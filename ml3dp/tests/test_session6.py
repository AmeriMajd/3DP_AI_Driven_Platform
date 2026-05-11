"""Session 6 verification tests."""
from __future__ import annotations

import sys
from pathlib import Path
from unittest.mock import MagicMock

import numpy as np
import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))


# ─── helpers ──────────────────────────────────────────────────────────────────

def _make_mock_trial():
    trial = MagicMock()
    trial.suggest_int.side_effect = lambda name, lo, hi, **kw: lo
    trial.suggest_float.side_effect = lambda name, lo, hi, **kw: lo
    trial.suggest_categorical.side_effect = lambda name, choices: choices[0]
    return trial


def _make_tiny_splits():
    import tempfile
    from src.ml3dp.data import GeneratorConfig, generate_dataset
    from src.ml3dp.features.prepare import prepare_all_stages

    cfg = GeneratorConfig(n_samples=400, seed=42)
    with tempfile.TemporaryDirectory() as tmp:
        df = generate_dataset(cfg, out_dir=tmp, name="smoke", verbose=False)
    return prepare_all_stages(df)


_TUNED_PARAMS_SMALL = {
    "stage1_tech": {
        "family": "lightgbm",
        "best_params": {
            "n_estimators": 10,
            "num_leaves": 15,
            "learning_rate": 0.1,
            "min_child_samples": 5,
            "reg_alpha": 0.01,
        },
    },
    "stage2_fdm": {
        "family": "random_forest",
        "best_params": {
            "n_estimators": 10,
            "max_depth": 5,
            "min_samples_leaf": 1,
            "max_features": "sqrt",
        },
    },
    "stage2_sla": {
        "family": "lightgbm",
        "best_params": {
            "n_estimators": 10,
            "num_leaves": 15,
            "learning_rate": 0.1,
            "min_child_samples": 5,
            "reg_alpha": 0.01,
        },
    },
    "stage3_fdm": {
        "family": "random_forest",
        "best_params": {
            "n_estimators": 10,
            "max_depth": 5,
            "min_samples_leaf": 1,
            "max_features": "sqrt",
        },
    },
    "stage3_sla": {
        "family": "random_forest",
        "best_params": {
            "n_estimators": 10,
            "max_depth": 5,
            "min_samples_leaf": 1,
            "max_features": "sqrt",
        },
    },
}


@pytest.fixture(scope="module")
def tiny_splits():
    return _make_tiny_splits()


# ─── test_search_spaces_callable ──────────────────────────────────────────────

def test_search_spaces_callable():
    from src.ml3dp.tuning.search_spaces import CLASSIFIER_SPACES, REGRESSOR_SPACES

    trial = _make_mock_trial()
    for fn in list(CLASSIFIER_SPACES.values()) + list(REGRESSOR_SPACES.values()):
        result = fn(trial)
        assert isinstance(result, dict)
        assert len(result) > 0


# ─── test_tune_stage_smoke ─────────────────────────────────────────────────────

def test_tune_stage_smoke(tiny_splits):
    from src.ml3dp.tuning.optimizer import tune_stage

    result = tune_stage("stage1_tech", "lightgbm", tiny_splits, n_trials=2, seed=42)
    assert set(result.keys()) >= {"stage", "family", "best_params", "best_value", "n_trials"}
    assert isinstance(result["best_params"], dict)
    assert isinstance(result["best_value"], float)


# ─── test_train_final_smoke ────────────────────────────────────────────────────

def test_train_final_smoke(tmp_path, tiny_splits):
    from src.ml3dp.evaluation.final import train_final_models

    summary = train_final_models(tiny_splits, _TUNED_PARAMS_SMALL, out_dir=tmp_path)
    assert len(summary) == 5
    for path_str in summary["model_path"]:
        assert Path(path_str).exists()


# ─── test_final_models_loadable ───────────────────────────────────────────────

def test_final_models_loadable(tmp_path, tiny_splits):
    import joblib
    from src.ml3dp.evaluation.final import train_final_models

    summary = train_final_models(tiny_splits, _TUNED_PARAMS_SMALL, out_dir=tmp_path)
    for path_str in summary["model_path"]:
        model = joblib.load(path_str)
        assert hasattr(model, "predict")


# ─── test_final_results_columns ───────────────────────────────────────────────

def test_final_results_columns(tmp_path, tiny_splits):
    from src.ml3dp.evaluation.final import train_final_models

    summary = train_final_models(tiny_splits, _TUNED_PARAMS_SMALL, out_dir=tmp_path)
    expected = {
        "stage", "family", "test_metric_primary", "test_metric_secondary",
        "passed_threshold", "model_path", "n_train_samples",
    }
    assert expected.issubset(set(summary.columns))


# ─── test_pass_fail_logic ──────────────────────────────────────────────────────

def test_pass_fail_logic(tmp_path, tiny_splits):
    from src.ml3dp.evaluation.final import train_final_models

    summary = train_final_models(tiny_splits, _TUNED_PARAMS_SMALL, out_dir=tmp_path)
    for val in summary["passed_threshold"]:
        assert isinstance(val, (bool, np.bool_))


# ─── Standalone runner ────────────────────────────────────────────────────────

def _run_all() -> None:
    import tempfile

    print("Building tiny splits (n=400) …")
    splits = _make_tiny_splits()

    def with_splits(fn):
        return lambda: fn(splits)

    def with_tmp_and_splits(fn):
        def _run():
            with tempfile.TemporaryDirectory() as tmp:
                fn(Path(tmp), splits)
        return _run

    tests = [
        test_search_spaces_callable,
        with_splits(test_tune_stage_smoke),
        with_tmp_and_splits(test_train_final_smoke),
        with_tmp_and_splits(test_final_models_loadable),
        with_tmp_and_splits(test_final_results_columns),
        with_tmp_and_splits(test_pass_fail_logic),
    ]
    names = [
        "test_search_spaces_callable",
        "test_tune_stage_smoke",
        "test_train_final_smoke",
        "test_final_models_loadable",
        "test_final_results_columns",
        "test_pass_fail_logic",
    ]

    failed = 0
    for t, name in zip(tests, names):
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
    # Ensure src.ml3dp is importable when run directly
    sys.path.insert(0, str(ROOT))
    _run_all()
