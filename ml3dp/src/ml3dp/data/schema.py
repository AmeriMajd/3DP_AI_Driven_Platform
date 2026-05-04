"""
src/ml3dp/data/schema.py

Single source of truth for the ML module's feature schema, label spaces,
and parameter ranges.

Every other module imports from here. If anything in the input/output
contract changes, it changes here first and everywhere else follows.

The contents of this file are derived from:
    - 16 geometry features (handoff Section 3.1)
    - 6 user intent features (handoff Section 3.2)
    - Stage 1: FDM / SLA
    - Stage 2-FDM: 4 materials  — aligned with the FastAPI backend
    - Stage 2-SLA: 2 materials  — aligned with the FastAPI backend
    - Stage 3 parameter ranges (handoff Section 4)

Note: the handoff document originally listed 6 FDM and 5 SLA materials,
but the deployed backend (recommendation_service.py, ml_inference.py)
exposes only 4 FDM (PLA/ABS/PETG/TPU) and 2 SLA (Resin-Std/Resin-Eng).
We follow the deployed contract, not the handoff, since the model output
must match what the API serves. This narrower vocabulary is documented
in docs/crisp-dm/01_business_understanding.md.
"""

from __future__ import annotations

# ─── Geometry features (16) ───────────────────────────────────────────────────
# Numeric features extracted automatically from the STL mesh.
GEOMETRY_FEATURES: list[str] = [
    "volume_cm3",
    "surface_area_cm2",
    "bbox_x_mm",
    "bbox_y_mm",
    "bbox_z_mm",
    "triangle_count",
    "overhang_ratio",
    "max_overhang_angle",
    "min_wall_thickness_mm",
    "avg_wall_thickness_mm",
    "complexity_index",
    "aspect_ratio",
    "is_watertight",          # boolean (0/1)
    "shell_count",
    "com_offset_ratio",
    "flat_base_area_mm2",
]

# ─── User intent features (6) ─────────────────────────────────────────────────
# Categorical features provided by the user at request time.
INTENT_FEATURES: list[str] = [
    "intended_use",
    "surface_finish",
    "needs_flexibility",
    "strength_required",
    "budget_priority",
    "outdoor_use",
]

# Allowed values per intent feature. Used for validation and label encoding.
INTENT_VALUES: dict[str, list] = {
    "intended_use":      ["decorative", "functional", "mechanical", "prototype"],
    "surface_finish":    ["rough", "standard", "smooth", "fine"],
    "needs_flexibility": [False, True],
    "strength_required": ["low", "medium", "high"],
    "budget_priority":   ["cost", "balanced", "quality"],
    "outdoor_use":       [False, True],
}

# ─── All input features (geometry + intent) ───────────────────────────────────
ALL_FEATURES: list[str] = GEOMETRY_FEATURES + INTENT_FEATURES
N_FEATURES: int = len(ALL_FEATURES)  # = 22 (per handoff Section 3)

assert N_FEATURES == 22, f"Expected 22 features per handoff, got {N_FEATURES}"

# ─── Label spaces ─────────────────────────────────────────────────────────────

# Stage 1 — Technology (binary)
TECHNOLOGIES: list[str] = ["FDM", "SLA"]

# Stage 2-FDM — Material (4 classes; matches FastAPI backend)
FDM_MATERIALS: list[str] = ["PLA", "ABS", "PETG", "TPU"]

# Stage 2-SLA — Material (2 classes; matches FastAPI backend)
SLA_MATERIALS: list[str] = ["Resin-Std", "Resin-Eng"]

# ─── Stage 3 parameter ranges ─────────────────────────────────────────────────
# Per-parameter (min, max) used for: clamping predictions, computing
# MAE-as-percent-of-range, and validating generated rows.

FDM_PARAM_RANGES: dict[str, tuple[float, float]] = {
    "layer_height_mm":      (0.08, 0.32),
    "infill_pct":           (10.0, 100.0),
    "print_speed_mm_s":     (15.0, 100.0),
    "wall_count":           (2.0, 6.0),       # integer at output but float internally
    "fan_speed_pct":        (0.0, 100.0),
    "support_density_pct":  (0.0, 80.0),
}

SLA_PARAM_RANGES: dict[str, tuple[float, float]] = {
    "layer_height_mm":      (0.025, 0.10),
    "exposure_s":           (1.0, 15.0),
    "bottom_exposure_s":    (5.0, 60.0),
    "lift_distance_mm":     (3.0, 12.0),
    "lift_speed_mm_s":      (20.0, 100.0),
    "support_density_pct":  (0.0, 80.0),
}

FDM_PARAM_NAMES: list[str] = list(FDM_PARAM_RANGES.keys())
SLA_PARAM_NAMES: list[str] = list(SLA_PARAM_RANGES.keys())


# ─── Sanity checks ────────────────────────────────────────────────────────────
def _self_check() -> None:
    """Run when imported; cheap. Catches accidental edits."""
    assert len(GEOMETRY_FEATURES) == 16
    assert len(INTENT_FEATURES) == 6
    assert len(TECHNOLOGIES) == 2
    assert len(FDM_MATERIALS) == 4
    assert len(SLA_MATERIALS) == 2
    assert len(FDM_PARAM_RANGES) == 6
    assert len(SLA_PARAM_RANGES) == 6
    # Param ranges must be (lo, hi) with lo < hi
    for tech_ranges in (FDM_PARAM_RANGES, SLA_PARAM_RANGES):
        for name, (lo, hi) in tech_ranges.items():
            assert lo < hi, f"Bad range for {name}: ({lo}, {hi})"


_self_check()
