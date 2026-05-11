"""
tests/test_session4.py

Verification tests for the Session 4 cross-family benchmark.

Run with:
    python tests/test_session4.py
"""

from __future__ import annotations

import sys
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from ml3dp.benchmark.runner import run_benchmark, select_winners
from ml3dp.features.prepare import prepare_all_stages

_SPLITS_CACHE: dict | None = None


def _get_splits() -> dict:
    global _SPLITS_CACHE
    if _SPLITS_CACHE is None:
        df = pd.read_parquet(ROOT / "data" / "synthetic_v3.parquet")
        _SPLITS_CACHE = prepare_all_stages(df, encoder_kind="ordinal")
    return _SPLITS_CACHE


def test_smoke_benchmark_runs() -> None:
    splits = _get_splits()
    results = run_benchmark(splits, smoke=True)
    assert isinstance(results, pd.DataFrame)
    assert len(results) > 0, "Smoke benchmark returned empty DataFrame"
    print("PASS test_smoke_benchmark_runs")


def test_results_shape() -> None:
    splits = _get_splits()
    results = run_benchmark(splits, smoke=True)
    required = {"stage", "family", "seed", "metric_primary", "metric_secondary", "passed_threshold"}
    missing = required - set(results.columns)
    assert not missing, f"Missing columns: {missing}"
    print("PASS test_results_shape")


def test_winners_one_per_stage() -> None:
    splits = _get_splits()
    results = run_benchmark(splits, smoke=True)
    winners = select_winners(results)
    assert len(winners) == 5, f"Expected 5 winners, got {len(winners)}: {winners}"
    expected_stages = {"stage1_tech", "stage2_fdm", "stage2_sla", "stage3_fdm", "stage3_sla"}
    assert set(winners.keys()) == expected_stages
    print("PASS test_winners_one_per_stage")


def test_threshold_column_present() -> None:
    splits = _get_splits()
    results = run_benchmark(splits, smoke=True)
    assert "passed_threshold" in results.columns
    assert results["passed_threshold"].dtype == bool or results["passed_threshold"].isin([True, False]).all()
    print("PASS test_threshold_column_present")


def test_xgboost_sample_weights_applied() -> None:
    """XGBoost on multiclass Stage 2-FDM must not crash."""
    splits = _get_splits()
    from ml3dp.benchmark.candidates import CLASSIFIERS
    from ml3dp.benchmark.runner import _clone_with_seed, _fit

    model = _clone_with_seed(CLASSIFIERS["xgboost"], seed=0)
    split = splits["stage2_fdm"]
    _fit(model, "xgboost", split.X_train, split.y_train)
    preds = model.predict(split.X_val)
    assert len(preds) == len(split.y_val)
    print("PASS test_xgboost_sample_weights_applied")


def test_regression_mae_pct_in_range() -> None:
    splits = _get_splits()
    results = run_benchmark(splits, smoke=True)
    mae_cols = [c for c in results.columns if c.startswith("mae_pct_")]
    assert mae_cols, "No mae_pct columns found in results"
    reg_rows = results[results["stage"].str.startswith("stage3")]
    for col in mae_cols:
        vals = reg_rows[col].dropna()
        assert (vals >= 0).all() and (vals <= 100).all(), (
            f"Column {col} has out-of-range values: {vals.describe()}"
        )
    print("PASS test_regression_mae_pct_in_range")


if __name__ == "__main__":
    tests = [
        test_smoke_benchmark_runs,
        test_results_shape,
        test_winners_one_per_stage,
        test_threshold_column_present,
        test_xgboost_sample_weights_applied,
        test_regression_mae_pct_in_range,
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
