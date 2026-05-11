"""Unit tests for estimation_service.

Wide gaps and explicit margins on monotonicity tests to avoid float-noise
flakiness in CI.
"""
import pytest

from app.core import pricing_config as pc
from app.services.estimation_service import estimate, EstimationResult


# ── Fixtures ─────────────────────────────────────────────────────────────────

def _geo_normal() -> dict:
    return {
        "volume_cm3": 50.0,
        "surface_area_cm2": 120.0,
        "bbox_x_mm": 60.0,
        "bbox_y_mm": 60.0,
        "bbox_z_mm": 40.0,
    }


def _params_fdm(**overrides) -> dict:
    base = {
        "technology": "FDM",
        "material": "PLA",
        "layer_height": 0.20,
        "infill_density": 30,
        "print_speed": 50,
        "wall_count": 3,
    }
    base.update(overrides)
    return base


def _params_sla(**overrides) -> dict:
    base = {
        "technology": "SLA",
        "material": "Resin-Standard",
        "layer_height": 0.05,
    }
    base.update(overrides)
    return base


def _orientation(support_mm3: float = 500.0, height_mm: float = 40.0) -> dict:
    return {
        "support_volume_mm3": support_mm3,
        "print_height_mm": height_mm,
    }


# ── Smoke tests ──────────────────────────────────────────────────────────────

def test_basic_fdm_returns_positive_values():
    r = estimate(_geo_normal(), _params_fdm(), _orientation())
    assert isinstance(r, EstimationResult)
    assert r.estimated_cost is not None and r.estimated_cost > 0
    assert r.estimated_time_minutes is not None and r.estimated_time_minutes > 0
    assert r.currency == "TND"
    assert r.pricing_version  # non-empty


def test_basic_sla_returns_positive_values():
    r = estimate(_geo_normal(), _params_sla(), _orientation())
    assert r.estimated_cost is not None and r.estimated_cost > 0
    assert r.estimated_time_minutes is not None and r.estimated_time_minutes > 0


# ── Monotonicity (wide gaps + 15% margin) ────────────────────────────────────

def test_higher_infill_increases_cost_and_time():
    low = estimate(_geo_normal(), _params_fdm(infill_density=10), _orientation())
    high = estimate(_geo_normal(), _params_fdm(infill_density=60), _orientation())
    assert high.estimated_cost > low.estimated_cost * 1.15
    assert high.estimated_time_minutes > low.estimated_time_minutes * 1.15


def test_heavier_supports_increase_cost():
    no_supports = estimate(_geo_normal(), _params_fdm(), _orientation(support_mm3=0))
    heavy = estimate(_geo_normal(), _params_fdm(), _orientation(support_mm3=5000))
    assert heavy.estimated_cost > no_supports.estimated_cost * 1.10


def test_faster_speed_shortens_time():
    slow = estimate(_geo_normal(), _params_fdm(print_speed=30), _orientation())
    fast = estimate(_geo_normal(), _params_fdm(print_speed=80), _orientation())
    assert fast.estimated_time_minutes < slow.estimated_time_minutes * 0.85


# ── Sanity bounds ────────────────────────────────────────────────────────────

def test_sanity_bound_giant_volume_returns_null():
    geo = _geo_normal() | {"volume_cm3": 50000.0}
    r = estimate(geo, _params_fdm(), _orientation())
    assert r.estimated_cost is None
    assert r.estimated_time_minutes is None
    assert r.warnings  # at least one warning


def test_zero_throughput_returns_null_time():
    r = estimate(_geo_normal(), _params_fdm(print_speed=0), _orientation())
    assert r.estimated_time_minutes is None
    assert r.estimated_cost is None


def test_zero_layer_height_returns_null():
    r = estimate(_geo_normal(), _params_fdm(layer_height=0), _orientation())
    assert r.estimated_time_minutes is None


# ── Confidence flag ──────────────────────────────────────────────────────────

def test_confidence_low_when_orientation_missing():
    r = estimate(_geo_normal(), _params_fdm(), None)
    assert r.confidence == "low"


def test_confidence_low_for_tiny_part():
    geo = _geo_normal() | {"volume_cm3": 0.5}
    r = estimate(geo, _params_fdm(), _orientation())
    assert r.confidence == "low"


def test_confidence_low_for_extreme_aspect_ratio():
    # Tall thin part: bbox_z=400, bbox_x=bbox_y=20 → aspect ratio 20
    geo = _geo_normal() | {"bbox_x_mm": 20, "bbox_y_mm": 20, "bbox_z_mm": 400}
    r = estimate(geo, _params_fdm(), _orientation())
    assert r.confidence == "low"


def test_confidence_high_for_normal_fdm_print():
    r = estimate(_geo_normal(), _params_fdm(), _orientation())
    assert r.confidence == "high"


def test_confidence_low_when_material_unknown():
    r = estimate(_geo_normal(), _params_fdm(material="Unobtanium"), _orientation())
    assert r.confidence == "low"


# ── Pricing version ──────────────────────────────────────────────────────────

def test_result_carries_pricing_version():
    r = estimate(_geo_normal(), _params_fdm(), _orientation())
    assert r.pricing_version == pc.PRICING_VERSION
    assert r.to_dict()["pricing_version"]


# ── Geometry-aware overhead ──────────────────────────────────────────────────

def test_tall_part_takes_longer_than_flat_part_same_volume():
    # Same volume/surface, different bbox shape → different overhead factor.
    base_geo = {"volume_cm3": 50.0, "surface_area_cm2": 120.0}
    tall = base_geo | {"bbox_x_mm": 30, "bbox_y_mm": 30, "bbox_z_mm": 200}
    flat = base_geo | {"bbox_x_mm": 80, "bbox_y_mm": 80, "bbox_z_mm": 30}

    r_tall = estimate(tall, _params_fdm(), _orientation(height_mm=200))
    r_flat = estimate(flat, _params_fdm(), _orientation(height_mm=30))
    assert r_tall.estimated_time_minutes > r_flat.estimated_time_minutes


# ── Defensive behavior ──────────────────────────────────────────────────────

def test_unknown_material_falls_back_to_defaults():
    r = estimate(_geo_normal(), _params_fdm(material="Unobtanium"), _orientation())
    assert r.estimated_cost is not None
    assert r.estimated_time_minutes is not None
    assert any("unknown material" in w.lower() for w in r.warnings)


def test_unknown_technology_falls_back_to_fdm():
    r = estimate(_geo_normal(), _params_fdm(technology="LASER"), _orientation())
    assert r.estimated_cost is not None
    assert any("unknown technology" in w.lower() for w in r.warnings)


def test_missing_geometry_returns_null_no_exception():
    r = estimate({}, _params_fdm(), _orientation())
    assert r.estimated_cost is None
    assert r.estimated_time_minutes is None


def test_none_inputs_do_not_raise():
    r = estimate(None, None, None)
    assert r.estimated_cost is None
    assert r.estimated_time_minutes is None


def test_to_dict_shape():
    r = estimate(_geo_normal(), _params_fdm(), _orientation())
    d = r.to_dict()
    assert set(d.keys()) == {
        "estimated_cost",
        "estimated_time_minutes",
        "currency",
        "pricing_version",
        "estimation_confidence",
    }
