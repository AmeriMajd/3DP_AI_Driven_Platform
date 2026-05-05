"""
tests/test_session3.py

Verification tests for the Session 3 data preparation pipeline.

Run with:
    python tests/test_session3.py
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from ml3dp.data.schema import ALL_FEATURES, FDM_MATERIALS, INTENT_VALUES, SLA_MATERIALS
from ml3dp.features.encoder import (
    INTENT_CATEGORICAL,
    OneHotIntentEncoder,
    OrdinalIntentEncoder,
)
from ml3dp.features.prepare import prepare_all_stages, save_splits, summarize_splits
from ml3dp.features.splits import make_split

_DATA_CACHE: pd.DataFrame | None = None
_SPLITS_CACHE: dict[str, object] | None = None


def test_ordinal_encoder_roundtrip() -> None:
    df = _load_df()
    encoder = OrdinalIntentEncoder()
    encoded = encoder.fit_transform(df[ALL_FEATURES])
    decoded = encoder.inverse_transform(encoded)
    for col in INTENT_CATEGORICAL:
        assert decoded[col].equals(df[col]), f"roundtrip mismatch for {col}"


def test_onehot_encoder_column_count() -> None:
    df = _load_df()
    encoder = OneHotIntentEncoder()
    encoded = encoder.fit_transform(df[ALL_FEATURES])
    assert encoded.shape[1] == 32, f"expected 32 columns, got {encoded.shape[1]}"


def test_onehot_encoder_no_unknown_levels() -> None:
    df = _load_df()
    encoder = OneHotIntentEncoder()
    encoded = encoder.fit_transform(df[ALL_FEATURES])
    for col in encoded.columns:
        if "__" in col:
            parent, level = col.split("__", 1)
            assert parent in INTENT_VALUES, f"unexpected one-hot parent: {parent}"
            allowed = {str(value) for value in INTENT_VALUES[parent]}
            assert level in allowed, f"unexpected level for {parent}: {level}"


def test_split_ratios() -> None:
    df = pd.DataFrame({"x": np.arange(1000), "y": np.arange(1000) % 2})
    split = make_split(df, ["x"], "y", None, seed=1337)
    _assert_ratio(len(split.X_train), 1000, 0.70)
    _assert_ratio(len(split.X_val), 1000, 0.15)
    _assert_ratio(len(split.X_test), 1000, 0.15)


def test_split_no_leakage() -> None:
    df = pd.DataFrame({"x": np.arange(200), "y": np.arange(200) % 2})
    split = make_split(df, ["x"], "y", None, seed=1337)
    all_idx = pd.Index(split.X_train.index).append(
        pd.Index(split.X_val.index)
    ).append(pd.Index(split.X_test.index))
    assert all_idx.is_unique, "duplicated indices across splits"
    assert len(all_idx) == len(df), "split sizes do not sum to input length"


def test_split_stratification() -> None:
    labels = np.array(["A"] * 800 + ["B"] * 200)
    df = pd.DataFrame({"x": np.arange(1000), "y": labels})
    split = make_split(df, ["x"], "y", "y", seed=1337)
    overall = df["y"].value_counts(normalize=True)
    for subset in (split.y_train, split.y_val, split.y_test):
        subset_props = subset.value_counts(normalize=True)
        for label, pct in overall.items():
            assert abs(subset_props.get(label, 0.0) - pct) <= 0.02, (
                f"stratification mismatch for {label}: {subset_props.get(label, 0.0):.3f}"
            )


def test_prepare_all_stages_returns_5() -> None:
    splits = _prepare_splits()
    expected = {"stage1_tech", "stage2_fdm", "stage2_sla", "stage3_fdm", "stage3_sla"}
    assert set(splits.keys()) == expected, f"unexpected split keys: {sorted(splits)}"


def test_stage2_fdm_only_fdm_rows() -> None:
    splits = _prepare_splits()
    stage2_fdm = splits["stage2_fdm"]
    stage2_sla = splits["stage2_sla"]
    assert set(stage2_fdm.y_train.unique()).issubset(set(FDM_MATERIALS))
    assert set(stage2_sla.y_train.unique()).issubset(set(SLA_MATERIALS))


def test_stage3_includes_material_onehot() -> None:
    splits = _prepare_splits()
    stage3_fdm = splits["stage3_fdm"]
    stage3_sla = splits["stage3_sla"]
    for material in FDM_MATERIALS:
        assert f"material__{material}" in stage3_fdm.X_train.columns
    for material in SLA_MATERIALS:
        assert f"material__{material}" in stage3_sla.X_train.columns


def test_summarize_splits_shape() -> None:
    splits = _prepare_splits()
    summary = summarize_splits(splits)
    expected_cols = [
        "stage_name",
        "n_train",
        "n_val",
        "n_test",
        "n_features",
        "target_kind",
    ]
    assert list(summary.columns) == expected_cols
    assert len(summary) == 5


def test_save_and_reload() -> None:
    from tempfile import TemporaryDirectory

    splits = _prepare_splits()
    with TemporaryDirectory() as tmp:
        out_dir = Path(tmp) / "prepared"
        save_splits(splits, out_dir)
        stage = splits["stage1_tech"]
        stage_dir = out_dir / stage.stage_name
        X_train = pd.read_parquet(stage_dir / "X_train.parquet")
        X_val = pd.read_parquet(stage_dir / "X_val.parquet")
        X_test = pd.read_parquet(stage_dir / "X_test.parquet")
        y_train = pd.read_parquet(stage_dir / "y_train.parquet")
        y_val = pd.read_parquet(stage_dir / "y_val.parquet")
        y_test = pd.read_parquet(stage_dir / "y_test.parquet")

        assert X_train.shape == stage.X_train.shape
        assert X_val.shape == stage.X_val.shape
        assert X_test.shape == stage.X_test.shape

        expected_y = _expected_y_shape(stage.y_train)
        assert y_train.shape == expected_y
        assert y_val.shape == _expected_y_shape(stage.y_val)
        assert y_test.shape == _expected_y_shape(stage.y_test)


def _assert_ratio(actual_count: int, total: int, expected: float) -> None:
    actual = actual_count / total
    assert abs(actual - expected) <= 0.01, f"ratio {actual:.3f} not near {expected:.2f}"


def _expected_y_shape(values: pd.Series | pd.DataFrame) -> tuple[int, int]:
    if isinstance(values, pd.Series):
        return (len(values), 1)
    return values.shape


def _load_df() -> pd.DataFrame:
    global _DATA_CACHE
    if _DATA_CACHE is None:
        _DATA_CACHE = pd.read_parquet(ROOT / "data" / "synthetic_v3.parquet")
    return _DATA_CACHE.copy()


def _prepare_splits() -> dict[str, object]:
    global _SPLITS_CACHE
    if _SPLITS_CACHE is None:
        _SPLITS_CACHE = prepare_all_stages(_load_df())
    return _SPLITS_CACHE


def _run_all() -> None:
    tests = [
        test_ordinal_encoder_roundtrip,
        test_onehot_encoder_column_count,
        test_onehot_encoder_no_unknown_levels,
        test_split_ratios,
        test_split_no_leakage,
        test_split_stratification,
        test_prepare_all_stages_returns_5,
        test_stage2_fdm_only_fdm_rows,
        test_stage3_includes_material_onehot,
        test_summarize_splits_shape,
        test_save_and_reload,
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
