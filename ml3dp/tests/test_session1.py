"""
tests/test_session1.py

Verification tests for the Session 1 deliverable (dataset design).

Run with:
    python -m pytest tests/test_session1.py -v

Or, without pytest installed, run as a script:
    python tests/test_session1.py

Each test prints a clear pass/fail line so you can see what worked.
"""

from __future__ import annotations

import sys
from collections import Counter
from pathlib import Path

# Allow running standalone
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

import numpy as np
import pandas as pd

from ml3dp.data import GeneratorConfig, generate_dataset
from ml3dp.data import rules
from ml3dp.data.schema import (
    ALL_FEATURES,
    FDM_MATERIALS,
    FDM_PARAM_RANGES,
    GEOMETRY_FEATURES,
    INTENT_FEATURES,
    INTENT_VALUES,
    N_FEATURES,
    SLA_MATERIALS,
    SLA_PARAM_RANGES,
    TECHNOLOGIES,
)


# ─── 1. Schema sanity ─────────────────────────────────────────────────────────
def test_schema_counts():
    assert len(GEOMETRY_FEATURES) == 16
    assert len(INTENT_FEATURES) == 6
    assert N_FEATURES == 22
    assert len(ALL_FEATURES) == 22
    assert TECHNOLOGIES == ["FDM", "SLA"]
    assert len(FDM_MATERIALS) == 4, f"got {FDM_MATERIALS}"
    assert len(SLA_MATERIALS) == 2, f"got {SLA_MATERIALS}"
    assert len(FDM_PARAM_RANGES) == 6
    assert len(SLA_PARAM_RANGES) == 6


# ─── 2. Rules are deterministic ───────────────────────────────────────────────
def test_rules_deterministic():
    """Same row in -> same label out, every time."""
    row = {
        "volume_cm3": 100.0,
        "surface_area_cm2": 200.0,
        "bbox_x_mm": 50.0, "bbox_y_mm": 80.0, "bbox_z_mm": 50.0,
        "triangle_count": 10000, "overhang_ratio": 0.2,
        "max_overhang_angle": 45.0,
        "min_wall_thickness_mm": 1.5, "avg_wall_thickness_mm": 2.5,
        "complexity_index": 2.0, "aspect_ratio": 1.6,
        "is_watertight": 1, "shell_count": 1,
        "com_offset_ratio": 0.1, "flat_base_area_mm2": 2000.0,
        "intended_use": "functional", "surface_finish": "standard",
        "needs_flexibility": False, "strength_required": "medium",
        "budget_priority": "balanced", "outdoor_use": False,
    }
    a = rules.fdm_material_for(row)
    b = rules.fdm_material_for(row)
    assert a == b, "rules.fdm_material_for must be deterministic"


# ─── 3. Every material is reachable ───────────────────────────────────────────
def test_every_fdm_material_reachable():
    """Generate a dataset and check every FDM material appears at least once."""
    cfg = GeneratorConfig(n_samples=3000, seed=7, material_noise_prob=0.0)
    df = _generate_in_memory(cfg)
    fdm = df[df["technology"] == "FDM"]
    seen = set(fdm["material"].unique())
    missing = set(FDM_MATERIALS) - seen
    assert not missing, f"unreachable FDM materials: {missing}"


def test_every_sla_material_reachable():
    cfg = GeneratorConfig(n_samples=3000, seed=7, material_noise_prob=0.0)
    df = _generate_in_memory(cfg)
    sla = df[df["technology"] == "SLA"]
    seen = set(sla["material"].unique())
    missing = set(SLA_MATERIALS) - seen
    assert not missing, f"unreachable SLA materials: {missing}"


# ─── 4. Both technologies appear ──────────────────────────────────────────────
def test_both_technologies_present():
    cfg = GeneratorConfig(n_samples=2000, seed=7, material_noise_prob=0.0)
    df = _generate_in_memory(cfg)
    techs = set(df["technology"].unique())
    assert techs == {"FDM", "SLA"}, f"got {techs}"


# ─── 5. Per-row parameter completeness ────────────────────────────────────────
def test_per_row_param_completeness():
    """Every row must have its 6 technology-specific parameters filled in.

    Stage 3 has separate FDM and SLA regressors with different parameter sets.
    The generator stores all parameters as columns prefixed with `param_`, so
    FDM rows have NaN in SLA-only param columns and vice versa. This is by
    design — each Stage 3 regressor only trains on its own technology's rows.

    The actual correctness check is: a row tagged `technology=FDM` must have
    no NaN in the 6 FDM params; same for SLA.
    """
    cfg = GeneratorConfig(n_samples=500, seed=7)
    df = _generate_in_memory(cfg)

    fdm_cols = [f"param_{k}" for k in FDM_PARAM_RANGES]
    sla_cols = [f"param_{k}" for k in SLA_PARAM_RANGES]

    fdm_rows = df[df["technology"] == "FDM"]
    sla_rows = df[df["technology"] == "SLA"]

    fdm_nans = fdm_rows[fdm_cols].isna().sum().sum()
    sla_nans = sla_rows[sla_cols].isna().sum().sum()

    assert fdm_nans == 0, f"FDM rows have {fdm_nans} NaN values in FDM params"
    assert sla_nans == 0, f"SLA rows have {sla_nans} NaN values in SLA params"

    # Also check that geometry, intent, technology, material are never NaN
    core_cols = list(GEOMETRY_FEATURES) + list(INTENT_FEATURES) + ["technology", "material"]
    core_nans = df[core_cols].isna().sum().sum()
    assert core_nans == 0, f"core columns have {core_nans} NaN values"


# ─── 6. Geometry feature ranges are sane ──────────────────────────────────────
def test_geometry_ranges_sane():
    cfg = GeneratorConfig(n_samples=500, seed=7)
    df = _generate_in_memory(cfg)
    assert (df["volume_cm3"] > 0).all()
    assert (df["bbox_x_mm"] > 0).all()
    assert (df["bbox_y_mm"] > 0).all()
    assert (df["bbox_z_mm"] > 0).all()
    assert (df["triangle_count"] > 0).all()
    assert df["overhang_ratio"].between(0, 1).all()
    assert df["aspect_ratio"].between(1, 5).all()
    assert df["is_watertight"].isin([0, 1]).all()
    assert (df["com_offset_ratio"] >= 0).all()


# ─── 7. Parameters within schema ranges ───────────────────────────────────────
def test_parameters_within_ranges():
    cfg = GeneratorConfig(n_samples=500, seed=7)
    df = _generate_in_memory(cfg)
    fdm = df[df["technology"] == "FDM"]
    sla = df[df["technology"] == "SLA"]
    for name, (lo, hi) in FDM_PARAM_RANGES.items():
        col = f"param_{name}"
        assert col in df.columns, f"missing {col}"
        if len(fdm):
            assert fdm[col].between(lo, hi).all(), \
                f"{col} out of [{lo},{hi}] for FDM rows"
    for name, (lo, hi) in SLA_PARAM_RANGES.items():
        col = f"param_{name}"
        if len(sla):
            assert sla[col].between(lo, hi).all(), \
                f"{col} out of [{lo},{hi}] for SLA rows"


# ─── 8. Separability proof (the headline test for this session) ───────────────
def test_separability_no_noise():
    """With noise = 0, identical (geometry+intent) inputs must always
    produce identical material labels. This proves the rules carve up the
    feature space without overlap.

    We hash each row's input features and check that within each hash
    bucket, only one material label appears.
    """
    cfg = GeneratorConfig(n_samples=4000, seed=7, material_noise_prob=0.0,
                          param_noise_std=0.0)
    df = _generate_in_memory(cfg)

    # Build a hash key per row from input features only
    keys = df[ALL_FEATURES].astype(str).agg("|".join, axis=1)
    df = df.assign(_key=keys)

    grouped = df.groupby("_key")["material"].nunique()
    n_ambiguous = int((grouped > 1).sum())
    assert n_ambiguous == 0, (
        f"{n_ambiguous} input vectors map to multiple materials — rules overlap"
    )


# ─── 9. Noise actually does something ─────────────────────────────────────────
def test_noise_changes_labels():
    """When noise > 0, some rule-chosen labels should be flipped relative
    to the noise=0 baseline."""
    cfg_clean = GeneratorConfig(n_samples=2000, seed=7, material_noise_prob=0.0,
                                 param_noise_std=0.0)
    cfg_noisy = GeneratorConfig(n_samples=2000, seed=7, material_noise_prob=0.15,
                                 param_noise_std=0.0)
    clean = _generate_in_memory(cfg_clean)
    noisy = _generate_in_memory(cfg_noisy)
    diffs = (clean["material"] != noisy["material"]).sum()
    # Expect roughly 15% of rows different — accept anywhere in [5%, 25%].
    pct = diffs / len(clean)
    assert 0.05 <= pct <= 0.25, f"unexpected noise rate: {pct:.3f}"


# ─── helpers ──────────────────────────────────────────────────────────────────
def _generate_in_memory(cfg: GeneratorConfig) -> pd.DataFrame:
    """Generate without saving files (uses a temp dir we ignore)."""
    import tempfile
    with tempfile.TemporaryDirectory() as tmp:
        return generate_dataset(cfg, out_dir=tmp, name="_tmp", verbose=False)


# ─── Standalone runner ────────────────────────────────────────────────────────
def _run_all() -> None:
    tests = [
        test_schema_counts,
        test_rules_deterministic,
        test_every_fdm_material_reachable,
        test_every_sla_material_reachable,
        test_both_technologies_present,
        test_per_row_param_completeness,
        test_geometry_ranges_sane,
        test_parameters_within_ranges,
        test_separability_no_noise,
        test_noise_changes_labels,
    ]
    failed = 0
    for t in tests:
        name = t.__name__
        try:
            t()
            print(f"PASS  {name}")
        except AssertionError as e:
            failed += 1
            print(f"FAIL  {name}\n      {e}")
        except Exception as e:
            failed += 1
            print(f"ERROR {name}\n      {type(e).__name__}: {e}")
    print(f"\n{len(tests) - failed} / {len(tests)} passed")
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    _run_all()
