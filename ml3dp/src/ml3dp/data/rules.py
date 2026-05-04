"""
src/ml3dp/data/rules.py

Material decision rules for the synthetic dataset generator.

Design principle: each material owns a distinct region of the 22-feature
space. A material's "primary discriminator" is the field that uniquely
identifies it; "secondary discriminators" are tiebreakers when the primary
is ambiguous.

This separability is what gives the cascade a chance to hit the
acceptance thresholds (Stage 1 macro F1 >= 0.90, Stage 2 >= 0.85).

────────────────────────────────────────────────────────────────────────────
Stage 1 — Technology (FDM vs SLA)
────────────────────────────────────────────────────────────────────────────
SLA wins when:
  - surface_finish in {smooth, fine}, AND
  - the part fits in a small SLA build volume (bbox_x, y <= 145mm; z <= 175mm)
FDM wins by default.

Rationale: SLA's distinguishing capability is fine surface finish; its
distinguishing constraint is small build volume. Either signal alone is
ambiguous (a large smooth-finish part still has to be FDM); both together
are the SLA region.

────────────────────────────────────────────────────────────────────────────
Stage 2-FDM — Material (4 classes)
────────────────────────────────────────────────────────────────────────────

  TPU   — primary: needs_flexibility = True
          (no other FDM material is flexible — fully separable)

  ABS   — primary: outdoor_use = True
                   OR (strength_required = "high" AND
                       intended_use in {"functional", "mechanical"})
          (high-temp / UV-tolerant / tough engineering thermoplastic;
           the only FDM material in this vocabulary that handles
           outdoor exposure or heavy load)

  PETG  — primary: strength_required = "medium" AND
                   intended_use in {"functional", "mechanical"}
                   AND outdoor_use = False
          (medium-strength functional parts that don't need ABS's
           thermal/UV resistance)

  PLA   — default for everything else
          (decorative, low-strength, prototype, tight budget,
           cost-sensitive functional with low load).

The order matters: rules are evaluated top-to-bottom and the first match
wins. This makes the rule set deterministic and traceable.

────────────────────────────────────────────────────────────────────────────
Stage 2-SLA — Material (2 classes)
────────────────────────────────────────────────────────────────────────────

  Resin-Eng   — primary: strength_required = "high"
                         OR intended_use = "mechanical"
                (load-bearing or mechanically demanding SLA parts)

  Resin-Std   — default
                (decorative, prototype, low/medium strength).

────────────────────────────────────────────────────────────────────────────
Stage 3 — Parameters
────────────────────────────────────────────────────────────────────────────
Parameters are derived from material + a small subset of geometry/intent
fields with deterministic functions plus light noise. See
`fdm_parameters_for()` and `sla_parameters_for()` for the exact formulas.
"""

from __future__ import annotations

from typing import Any

import numpy as np

from .schema import (
    FDM_PARAM_RANGES,
    SLA_PARAM_RANGES,
)


# ─── Stage 1 — Technology rule ────────────────────────────────────────────────
# SLA build volume thresholds (typical desktop SLA: e.g. Form 3, Mars 4)
_SLA_BBOX_XY_MM = 145.0
_SLA_BBOX_Z_MM  = 175.0


def technology_for(row: dict[str, Any]) -> str:
    """Return 'FDM' or 'SLA' for a single feature row."""
    fine_finish = row["surface_finish"] in ("smooth", "fine")
    fits_sla = (
        row["bbox_x_mm"] <= _SLA_BBOX_XY_MM
        and row["bbox_y_mm"] <= _SLA_BBOX_XY_MM
        and row["bbox_z_mm"] <= _SLA_BBOX_Z_MM
    )
    return "SLA" if (fine_finish and fits_sla) else "FDM"


# ─── Stage 2-FDM — Material rule ──────────────────────────────────────────────
def fdm_material_for(row: dict[str, Any]) -> str:
    """Return one of {PLA, ABS, PETG, TPU}."""
    # 1. TPU is the only flexible FDM material — primary discriminator
    if row["needs_flexibility"]:
        return "TPU"

    # 2. ABS owns outdoor use + heavy-duty engineering parts
    if row["outdoor_use"]:
        return "ABS"
    if (
        row["strength_required"] == "high"
        and row["intended_use"] in ("functional", "mechanical")
    ):
        return "ABS"

    # 3. PETG is the medium-strength functional choice
    if (
        row["strength_required"] == "medium"
        and row["intended_use"] in ("functional", "mechanical")
    ):
        return "PETG"

    # 4. PLA is the default for everything else
    return "PLA"


# ─── Stage 2-SLA — Material rule ──────────────────────────────────────────────
def sla_material_for(row: dict[str, Any]) -> str:
    """Return one of {Resin-Std, Resin-Eng}."""
    if row["strength_required"] == "high" or row["intended_use"] == "mechanical":
        return "Resin-Eng"
    return "Resin-Std"


# ─── Stage 3-FDM — Parameter rules ────────────────────────────────────────────
# Each material has a base parameter profile. Geometry + intent then modulate
# specific parameters. The output is clamped to schema ranges and lightly
# noised by the generator (not here).

_FDM_BASE: dict[str, dict[str, float]] = {
    # layer_height tuned by material melt behaviour & detail tier
    # infill is base value; speed depends on material thermal limits
    "PLA":  {"layer_height_mm": 0.20, "infill_pct": 20, "print_speed_mm_s": 60,
             "wall_count": 3, "fan_speed_pct": 100, "support_density_pct": 15},
    "PETG": {"layer_height_mm": 0.20, "infill_pct": 30, "print_speed_mm_s": 50,
             "wall_count": 3, "fan_speed_pct":  50, "support_density_pct": 20},
    "ABS":  {"layer_height_mm": 0.20, "infill_pct": 35, "print_speed_mm_s": 45,
             "wall_count": 4, "fan_speed_pct":  20, "support_density_pct": 25},
    "TPU":  {"layer_height_mm": 0.20, "infill_pct": 25, "print_speed_mm_s": 25,
             "wall_count": 3, "fan_speed_pct":  60, "support_density_pct": 15},
}


def fdm_parameters_for(row: dict[str, Any], material: str) -> dict[str, float]:
    """Return the 6 FDM parameters for a row+material, before noise.

    Parameters are derived deterministically from the material baseline,
    then modulated by:
      - surface_finish    -> layer_height
      - strength_required -> infill_pct, wall_count
      - overhang_ratio    -> support_density_pct
    """
    base = dict(_FDM_BASE[material])

    # surface_finish controls layer height
    finish_to_lh = {"rough": 0.28, "standard": 0.20, "smooth": 0.12, "fine": 0.10}
    base["layer_height_mm"] = finish_to_lh[row["surface_finish"]]

    # strength controls infill and walls
    strength_infill_bonus = {"low": -10, "medium": 0, "high": +25}[row["strength_required"]]
    base["infill_pct"]    += strength_infill_bonus
    base["wall_count"]    += {"low": 0, "medium": 0, "high": 1}[row["strength_required"]]

    # overhang controls support density (more overhang → more support)
    base["support_density_pct"] = float(np.clip(
        15 + row["overhang_ratio"] * 60.0, 0, 80
    ))

    return _clip_to_ranges(base, FDM_PARAM_RANGES)


# ─── Stage 3-SLA — Parameter rules ────────────────────────────────────────────
_SLA_BASE: dict[str, dict[str, float]] = {
    "Resin-Std": {"layer_height_mm": 0.05, "exposure_s": 2.5, "bottom_exposure_s": 25,
                  "lift_distance_mm": 6, "lift_speed_mm_s": 60, "support_density_pct": 30},
    "Resin-Eng": {"layer_height_mm": 0.05, "exposure_s": 5.0, "bottom_exposure_s": 40,
                  "lift_distance_mm": 8, "lift_speed_mm_s": 45, "support_density_pct": 40},
}


def sla_parameters_for(row: dict[str, Any], material: str) -> dict[str, float]:
    """Return the 6 SLA parameters for a row+material, before noise.

    Parameters are derived deterministically from the material baseline,
    then modulated by:
      - surface_finish    -> layer_height
      - overhang_ratio    -> support_density_pct
    """
    base = dict(_SLA_BASE[material])

    finish_to_lh = {"rough": 0.10, "standard": 0.05, "smooth": 0.035, "fine": 0.025}
    base["layer_height_mm"] = finish_to_lh[row["surface_finish"]]

    base["support_density_pct"] = float(np.clip(
        25 + row["overhang_ratio"] * 50.0, 0, 80
    ))

    return _clip_to_ranges(base, SLA_PARAM_RANGES)


# ─── Helpers ──────────────────────────────────────────────────────────────────
def _clip_to_ranges(
    params: dict[str, float],
    ranges: dict[str, tuple[float, float]],
) -> dict[str, float]:
    """Clip every parameter to its valid (lo, hi) range from the schema."""
    out: dict[str, float] = {}
    for name, value in params.items():
        lo, hi = ranges[name]
        out[name] = float(np.clip(value, lo, hi))
    return out
