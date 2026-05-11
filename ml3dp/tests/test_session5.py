"""
tests/test_session5.py

Verification tests for Session 5 diagnostic utilities.

Run with:
    python tests/test_session5.py
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from ml3dp.diagnostic.ceiling import estimate_ceiling
from ml3dp.diagnostic.feature_importance import extract_importances
from ml3dp.diagnostic.per_class import confusion_matrix_df, per_class_breakdown
from ml3dp.features.prepare import prepare_all_stages

_DF_CACHE: pd.DataFrame | None = None
_SPLITS_CACHE: dict | None = None


def _get_df() -> pd.DataFrame:
    global _DF_CACHE
    if _DF_CACHE is None:
        _DF_CACHE = pd.read_parquet(ROOT / "data" / "synthetic_v3.parquet")
    return _DF_CACHE


def _get_splits() -> dict:
    global _SPLITS_CACHE
    if _SPLITS_CACHE is None:
        _SPLITS_CACHE = prepare_all_stages(_get_df())
    return _SPLITS_CACHE


# ─── 1. Ceiling within bounds ─────────────────────────────────────────────────
def test_ceiling_within_bounds() -> None:
    df = _get_df()
    for stage in ("stage1_tech", "stage2_fdm", "stage2_sla"):
        result = estimate_ceiling(df, stage)
        c = result["agreement_rate"]
        assert 0.0 <= c <= 1.0, f"{stage}: ceiling {c} out of [0,1]"
    print("PASS test_ceiling_within_bounds")


# ─── 2. Ceiling higher than random ────────────────────────────────────────────
def test_ceiling_higher_than_random() -> None:
    df = _get_df()
    random_baselines = {
        "stage1_tech": 0.5,   # binary
        "stage2_fdm": 0.25,   # 4 classes
        "stage2_sla": 0.5,    # 2 classes
    }
    for stage, baseline in random_baselines.items():
        result = estimate_ceiling(df, stage)
        c = result["agreement_rate"]
        assert c > baseline, f"{stage}: ceiling {c:.3f} not > random baseline {baseline}"
    print("PASS test_ceiling_higher_than_random")


# ─── 3. Per-class breakdown shape ─────────────────────────────────────────────
def test_per_class_breakdown_shape() -> None:
    y_true = ["A", "B", "A", "C", "B", "C"]
    y_pred = ["A", "B", "C", "C", "A", "C"]
    class_names = ["A", "B", "C"]
    df = per_class_breakdown(y_true, y_pred, class_names)
    expected_cols = {"class", "support", "precision", "recall", "f1", "n_misclassified"}
    assert expected_cols.issubset(set(df.columns)), f"Missing columns: {expected_cols - set(df.columns)}"
    assert len(df) == len(class_names)
    print("PASS test_per_class_breakdown_shape")


# ─── 4. Confusion matrix square ───────────────────────────────────────────────
def test_confusion_matrix_square() -> None:
    y_true = ["A", "B", "A", "C"]
    y_pred = ["A", "A", "C", "C"]
    class_names = ["A", "B", "C"]
    cm = confusion_matrix_df(y_true, y_pred, class_names)
    n = len(class_names)
    assert cm.shape == (n, n), f"Expected ({n},{n}), got {cm.shape}"
    assert list(cm.index) == class_names
    assert list(cm.columns) == class_names
    print("PASS test_confusion_matrix_square")


# ─── 5. Feature importances sum positive ──────────────────────────────────────
def test_feature_importance_sums_positive() -> None:
    from sklearn.ensemble import RandomForestClassifier
    splits = _get_splits()
    split = splits["stage1_tech"]
    model = RandomForestClassifier(n_estimators=10, random_state=0)
    model.fit(split.X_train, split.y_train)
    imp_df = extract_importances(model, split.feature_names)
    assert imp_df["importance"].sum() > 0, "Importances sum to zero"
    assert list(imp_df.columns) == ["feature", "importance", "rank"]
    print("PASS test_feature_importance_sums_positive")


# ─── 6. Diagnostic summary has 5 rows ─────────────────────────────────────────
def test_diagnostic_summary_5_rows() -> None:
    summary_path = ROOT / "reports" / "tables" / "05_diagnostic_summary.csv"
    if not summary_path.exists():
        print("SKIP test_diagnostic_summary_5_rows (run script first)")
        return
    summary = pd.read_csv(summary_path, keep_default_na=False)
    assert len(summary) == 5, f"Expected 5 rows, got {len(summary)}"
    print("PASS test_diagnostic_summary_5_rows")


# ─── 7. Failure mode values valid ─────────────────────────────────────────────
def test_failure_mode_values_valid() -> None:
    summary_path = ROOT / "reports" / "tables" / "05_diagnostic_summary.csv"
    if not summary_path.exists():
        print("SKIP test_failure_mode_values_valid (run script first)")
        return
    summary = pd.read_csv(summary_path, keep_default_na=False)
    valid = {"passed", "data_limited", "model_limited", "n/a"}
    bad = set(summary["failure_mode"].unique()) - valid
    assert not bad, f"Invalid failure_mode values: {bad}"
    print("PASS test_failure_mode_values_valid")


# ─── 8. Diagnostic outputs exist ──────────────────────────────────────────────
def test_diagnostic_outputs_exist() -> None:
    script = ROOT / "scripts" / "04_run_diagnostic.py"
    result = subprocess.run(
        [sys.executable, str(script)],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, f"Script failed:\n{result.stderr}"

    expected_files = [
        ROOT / "reports" / "tables" / "05_diagnostic_summary.csv",
        ROOT / "reports" / "05_diagnostic_report.json",
        ROOT / "reports" / "figures" / "05_confusion_stage1_tech.png",
        ROOT / "reports" / "figures" / "05_confusion_stage2_fdm.png",
        ROOT / "reports" / "figures" / "05_confusion_stage2_sla.png",
        ROOT / "reports" / "figures" / "05_importance_stage1_tech.png",
        ROOT / "reports" / "figures" / "05_importance_stage2_fdm.png",
        ROOT / "reports" / "figures" / "05_importance_stage2_sla.png",
        ROOT / "reports" / "figures" / "05_importance_stage3_fdm.png",
        ROOT / "reports" / "figures" / "05_importance_stage3_sla.png",
        ROOT / "reports" / "tables" / "05_per_class_stage1_tech.csv",
        ROOT / "reports" / "tables" / "05_per_class_stage2_fdm.csv",
        ROOT / "reports" / "tables" / "05_per_class_stage2_sla.csv",
    ]
    missing = [str(p) for p in expected_files if not p.exists()]
    assert not missing, f"Missing output files:\n" + "\n".join(missing)
    print("PASS test_diagnostic_outputs_exist")


if __name__ == "__main__":
    tests = [
        test_ceiling_within_bounds,
        test_ceiling_higher_than_random,
        test_per_class_breakdown_shape,
        test_confusion_matrix_square,
        test_feature_importance_sums_positive,
        test_diagnostic_summary_5_rows,
        test_failure_mode_values_valid,
        test_diagnostic_outputs_exist,
    ]
    failed = 0
    for t in tests:
        try:
            t()
        except Exception as exc:
            print(f"FAIL {t.__name__}: {exc}")
            failed += 1
    print(f"\n{len(tests) - failed}/{len(tests)} tests passed")
    sys.exit(failed)
