"""Final test-set evaluation and deployment-ready model saving."""
from __future__ import annotations

import json
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier, RandomForestRegressor
from sklearn.linear_model import Ridge
from sklearn.metrics import f1_score, mean_absolute_error
from sklearn.multioutput import MultiOutputRegressor
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import LabelEncoder, StandardScaler
from sklearn.utils.class_weight import compute_sample_weight

try:
    from lightgbm import LGBMClassifier, LGBMRegressor
except ImportError:
    LGBMClassifier = None  # type: ignore
    LGBMRegressor = None  # type: ignore

try:
    from xgboost import XGBClassifier
except ImportError:
    XGBClassifier = None  # type: ignore

from ml3dp.data.schema import FDM_PARAM_RANGES, SLA_PARAM_RANGES

_CLASSIFICATION_STAGES = {"stage1_tech", "stage2_fdm", "stage2_sla"}

THRESHOLDS: dict[str, float] = {
    "stage1_tech": 0.90,
    "stage2_fdm": 0.85,
    "stage2_sla": 0.85,
    "stage3_fdm": 10.0,
    "stage3_sla": 10.0,
}


def _build_clf(family: str, params: dict):
    if family == "random_forest":
        return RandomForestClassifier(**params, class_weight="balanced")
    if family == "lightgbm":
        return LGBMClassifier(**params, class_weight="balanced", verbose=-1)
    if family == "xgboost":
        return XGBClassifier(**params, eval_metric="mlogloss", verbosity=0)
    raise ValueError(f"Unknown classifier family: {family}")


def _build_reg(family: str, params: dict):
    if family == "random_forest":
        return MultiOutputRegressor(RandomForestRegressor(**params))
    if family == "ridge":
        inner = Pipeline([("scaler", StandardScaler()), ("clf", Ridge(alpha=params["alpha"]))])
        return MultiOutputRegressor(inner)
    if family == "lightgbm":
        return MultiOutputRegressor(LGBMRegressor(**params, verbose=-1))
    raise ValueError(f"Unknown regressor family: {family}")


def _param_ranges(stage_name: str) -> dict[str, tuple[float, float]]:
    return FDM_PARAM_RANGES if "fdm" in stage_name else SLA_PARAM_RANGES


def _eval_reg_test(
    model, X_test, y_test: pd.DataFrame, stage_name: str
) -> tuple[float, float]:
    y_pred = pd.DataFrame(model.predict(X_test), columns=y_test.columns)
    ranges = _param_ranges(stage_name)
    mae_pcts, mae_abs = [], []
    for col in y_test.columns:
        key = col.removeprefix("param_")
        lo, hi = ranges[key]
        mae = mean_absolute_error(y_test[col], y_pred[col])
        mae_pcts.append(mae / (hi - lo) * 100)
        mae_abs.append(mae)
    return float(np.mean(mae_pcts)), float(np.mean(mae_abs))


def train_final_models(
    splits: dict,
    tuned_params: dict,
    out_dir: Path,
) -> pd.DataFrame:
    """For each stage:
       1. Instantiate winner family with best_params
       2. Fit on train + val combined
       3. Evaluate on TEST set
       4. Save model to out_dir / {stage}_{family}.joblib
       5. Return summary DataFrame

    Summary columns:
      stage, family, test_metric_primary, test_metric_secondary,
      passed_threshold, model_path, n_train_samples
    """
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    rows = []
    for stage_name, stage_info in tuned_params.items():
        family = stage_info["family"]
        params = stage_info["best_params"]
        split = splits[stage_name]
        is_clf = stage_name in _CLASSIFICATION_STAGES

        X_trainval = pd.concat([split.X_train, split.X_val])
        y_trainval = pd.concat([split.y_train, split.y_val])
        n_train = len(X_trainval)

        model = _build_clf(family, params) if is_clf else _build_reg(family, params)
        le = None
        if is_clf and family == "xgboost":
            y_arr = y_trainval.to_numpy()
            le = LabelEncoder()
            y_enc = le.fit_transform(y_arr)
            sw = compute_sample_weight("balanced", y_enc)
            model.fit(X_trainval, y_enc, sample_weight=sw)
            model._le = le
        else:
            model.fit(X_trainval, y_trainval)

        model_path = out_dir / f"{stage_name}_{family}.joblib"
        if le is not None:
            joblib.dump({"model": model, "label_encoder": le}, model_path)
        else:
            joblib.dump(model, model_path)

        if is_clf:
            y_pred_raw = np.asarray(model.predict(split.X_test))
            if le is not None and y_pred_raw.dtype != object:
                y_pred = le.inverse_transform(y_pred_raw.astype(int))
            else:
                y_pred = y_pred_raw
            primary = float(f1_score(split.y_test, y_pred, average="macro"))
            secondary = float(f1_score(split.y_test, y_pred, average="weighted"))
            passed = bool(primary >= THRESHOLDS[stage_name])
        else:
            primary, secondary = _eval_reg_test(model, split.X_test, split.y_test, stage_name)
            passed = bool(primary <= THRESHOLDS[stage_name])

        rows.append({
            "stage": stage_name,
            "family": family,
            "test_metric_primary": primary,
            "test_metric_secondary": secondary,
            "passed_threshold": passed,
            "model_path": str(model_path),
            "n_train_samples": n_train,
        })

    return pd.DataFrame(rows)
