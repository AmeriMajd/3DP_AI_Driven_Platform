"""
Analytical print cost & time estimator.

Pure-function module: no DB, no FastAPI dependencies. Returns an
EstimationResult dataclass so the result can grow without breaking callers.

All errors become warnings on the result object — `estimate()` never raises.
"""
from __future__ import annotations

import logging
from dataclasses import dataclass, field, asdict
from typing import Any

from app.core import pricing_config as pc

logger = logging.getLogger(__name__)


@dataclass
class EstimationResult:
    estimated_cost: float | None
    estimated_time_minutes: int | None
    currency: str
    pricing_version: str
    confidence: str  # "high" | "low"
    warnings: list[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        """Backward-compatible flat dict for JSON / ORM merging.
        `warnings` are kept internal — not surfaced to API consumers."""
        return {
            "estimated_cost": self.estimated_cost,
            "estimated_time_minutes": self.estimated_time_minutes,
            "currency": self.currency,
            "pricing_version": self.pricing_version,
            "estimation_confidence": self.confidence,
        }


def _null_result(warnings: list[str], confidence: str = "low") -> EstimationResult:
    return EstimationResult(
        estimated_cost=None,
        estimated_time_minutes=None,
        currency=pc.CURRENCY,
        pricing_version=pc.PRICING_VERSION,
        confidence=confidence,
        warnings=warnings,
    )


def _density(material: str | None) -> tuple[float, bool]:
    if material and material in pc.MATERIAL_DENSITY_G_PER_CM3:
        return pc.MATERIAL_DENSITY_G_PER_CM3[material], True
    return pc.DEFAULT_DENSITY, False


def _price_per_kg(material: str | None) -> tuple[float, bool]:
    if material and material in pc.MATERIAL_PRICE_TND_PER_KG:
        return pc.MATERIAL_PRICE_TND_PER_KG[material], True
    return pc.DEFAULT_PRICE_PER_KG, False


def _machine_rate(technology: str) -> float:
    return pc.MACHINE_RATE_TND_PER_HOUR.get(technology, pc.DEFAULT_MACHINE_RATE)


def _aspect_ratio(geo: dict) -> float | None:
    bx = geo.get("bbox_x_mm")
    by = geo.get("bbox_y_mm")
    bz = geo.get("bbox_z_mm")
    if not all(isinstance(v, (int, float)) and v > 0 for v in (bx, by, bz)):
        return None
    avg_xy = max((bx + by) / 2.0, 1.0)
    return bz / avg_xy


def _overhead_factor(geo: dict) -> float:
    ar = _aspect_ratio(geo)
    if ar is None:
        return 1.40
    if ar > 3:
        return 1.55
    if ar < 0.5:
        return 1.30
    return 1.40


def _confidence_for(geo: dict, params: dict, orientation: dict | None,
                    material_known: bool) -> str:
    if orientation is None:
        return "low"
    vol = geo.get("volume_cm3")
    if isinstance(vol, (int, float)) and vol < 1.0:
        return "low"
    ar = _aspect_ratio(geo)
    if ar is not None and (ar > 5 or ar < 0.2):
        return "low"
    if not material_known:
        return "low"
    return "high"


def _apply_sanity_bounds(
    cost: float | None,
    time_minutes: int | None,
    effective_volume_cm3: float | None,
    warnings: list[str],
) -> tuple[float | None, int | None]:
    if effective_volume_cm3 is not None and effective_volume_cm3 > pc.MAX_EFFECTIVE_VOLUME_CM3:
        warnings.append(
            f"effective volume {effective_volume_cm3:.1f} cm³ exceeds max "
            f"{pc.MAX_EFFECTIVE_VOLUME_CM3} cm³ — discarding estimate"
        )
        return None, None
    if time_minutes is not None and time_minutes > pc.MAX_TIME_MINUTES:
        warnings.append(
            f"estimated time {time_minutes} min exceeds max "
            f"{pc.MAX_TIME_MINUTES} min — discarding estimate"
        )
        return None, None
    return cost, time_minutes


def _cost(effective_volume_cm3: float, total_time_seconds: float,
          material: str | None, technology: str) -> float:
    density, _ = _density(material)
    price_kg, _ = _price_per_kg(material)
    mass_g = effective_volume_cm3 * density
    material_cost = (mass_g / 1000.0) * price_kg
    machine_cost = (total_time_seconds / 3600.0) * _machine_rate(technology)
    return material_cost + machine_cost + pc.SETUP_FEE_TND


# ── FDM ──────────────────────────────────────────────────────────────────────

def _estimate_fdm(geo: dict, params: dict, orientation: dict | None,
                  warnings: list[str]) -> EstimationResult:
    volume_cm3 = geo.get("volume_cm3")
    surface_cm2 = geo.get("surface_area_cm2")
    if not (isinstance(volume_cm3, (int, float)) and volume_cm3 > 0
            and isinstance(surface_cm2, (int, float)) and surface_cm2 > 0):
        warnings.append("missing geometry (volume_cm3 or surface_area_cm2)")
        return _null_result(warnings)

    layer_height = params.get("layer_height")
    print_speed = params.get("print_speed")
    wall_count = params.get("wall_count") or 2
    infill_pct = params.get("infill_density") or 0
    material = params.get("material")

    if not (isinstance(layer_height, (int, float)) and layer_height > 0
            and isinstance(print_speed, (int, float)) and print_speed > 0):
        warnings.append("invalid layer_height or print_speed (must be > 0)")
        return _null_result(warnings)

    nozzle = pc.NOZZLE_WIDTH_MM

    # Shell volume (cm³) — cm³ = cm² × cm; shell_thickness mm → cm via /10.
    shell_thickness_mm = wall_count * nozzle
    raw_shell_cm3 = surface_cm2 * (shell_thickness_mm / 10.0)
    corrected_shell_cm3 = raw_shell_cm3 * pc.SHELL_EDGE_CORRECTION
    shell_cm3 = max(0.0, min(corrected_shell_cm3, volume_cm3 - 0.1))

    infill_cm3 = max(0.0, (volume_cm3 - shell_cm3) * (infill_pct / 100.0))

    support_cm3 = 0.0
    if orientation:
        sv_mm3 = orientation.get("support_volume_mm3")
        if isinstance(sv_mm3, (int, float)) and sv_mm3 > 0:
            support_cm3 = sv_mm3 / 1000.0

    effective_cm3 = shell_cm3 + infill_cm3 + support_cm3
    effective_mm3 = effective_cm3 * 1000.0

    throughput_mm3_s = print_speed * layer_height * nozzle
    if throughput_mm3_s <= 0:
        warnings.append("zero throughput — cannot estimate time")
        return _null_result(warnings)

    raw_time_s = effective_mm3 / throughput_mm3_s
    overhead = _overhead_factor(geo)
    total_time_s = raw_time_s * overhead

    _, material_known = _density(material)
    if not material_known:
        warnings.append(f"unknown material '{material}' — using PLA defaults")

    cost = _cost(effective_cm3, total_time_s, material, "FDM")
    minutes = int(round(total_time_s / 60.0))

    cost, minutes = _apply_sanity_bounds(cost, minutes, effective_cm3, warnings)

    return EstimationResult(
        estimated_cost=round(cost, 2) if cost is not None else None,
        estimated_time_minutes=minutes,
        currency=pc.CURRENCY,
        pricing_version=pc.PRICING_VERSION,
        confidence=_confidence_for(geo, params, orientation, material_known),
        warnings=warnings,
    )


# ── SLA ──────────────────────────────────────────────────────────────────────

def _estimate_sla(geo: dict, params: dict, orientation: dict | None,
                  warnings: list[str]) -> EstimationResult:
    volume_cm3 = geo.get("volume_cm3")
    if not (isinstance(volume_cm3, (int, float)) and volume_cm3 > 0):
        warnings.append("missing geometry (volume_cm3)")
        return _null_result(warnings)

    layer_height = params.get("layer_height")
    material = params.get("material")
    if not (isinstance(layer_height, (int, float)) and layer_height > 0):
        warnings.append("invalid layer_height (must be > 0)")
        return _null_result(warnings)

    build_height_mm: float | None = None
    if orientation:
        ph = orientation.get("print_height_mm")
        if isinstance(ph, (int, float)) and ph > 0:
            build_height_mm = float(ph)
    if build_height_mm is None:
        bz = geo.get("bbox_z_mm")
        if isinstance(bz, (int, float)) and bz > 0:
            build_height_mm = float(bz)
    if build_height_mm is None:
        warnings.append("no build height available")
        return _null_result(warnings)

    layer_count = build_height_mm / layer_height
    total_time_s = layer_count * pc.SLA_PER_LAYER_SECONDS

    effective_cm3 = volume_cm3  # SLA prints solid

    _, material_known = _density(material)
    if not material_known:
        warnings.append(f"unknown material '{material}' — using PLA-equivalent defaults")

    cost = _cost(effective_cm3, total_time_s, material, "SLA")
    minutes = int(round(total_time_s / 60.0))

    cost, minutes = _apply_sanity_bounds(cost, minutes, effective_cm3, warnings)

    return EstimationResult(
        estimated_cost=round(cost, 2) if cost is not None else None,
        estimated_time_minutes=minutes,
        currency=pc.CURRENCY,
        pricing_version=pc.PRICING_VERSION,
        confidence=_confidence_for(geo, params, orientation, material_known),
        warnings=warnings,
    )


# ── Public API ───────────────────────────────────────────────────────────────

def estimate(
    geo: dict | None,
    params: dict | None,
    orientation: dict | None,
) -> EstimationResult:
    """Estimate cost (TND) and time (minutes) for a print.
    Never raises — all failures become warnings on the returned result."""
    warnings: list[str] = []
    try:
        if not geo or not params:
            warnings.append("missing geo or params")
            return _null_result(warnings)

        technology = params.get("technology")
        if technology not in ("FDM", "SLA"):
            warnings.append(f"unknown technology '{technology}' — falling back to FDM")
            technology = "FDM"

        if technology == "SLA":
            return _estimate_sla(geo, params, orientation, warnings)
        return _estimate_fdm(geo, params, orientation, warnings)

    except Exception as exc:  # belt-and-braces; estimator must never raise
        logger.exception("estimation failed unexpectedly")
        warnings.append(f"unexpected error: {exc}")
        return _null_result(warnings)
