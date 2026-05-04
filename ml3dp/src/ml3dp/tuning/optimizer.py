"""Optuna optimizer per stage."""
from __future__ import annotations

import numpy as np
import optuna
import pandas as pd
from sklearn.ensemble import RandomForestClassifier, RandomForestRegressor
from sklearn.linear_model import Ridge
from sklearn.metrics import f1_score, mean_absolute_error
from sklearn.multioutput import MultiOutputRegressor
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import LabelEncoder, StandardScaler
from sklearn.utils.class_weight import compute_sample_weight

from ml3dp.data.schema import FDM_PARAM_RANGES, SLA_PARAM_RANGES
from ml3dp.tuning.search_spaces import CLASSIFIER_SPACES, REGRESSOR_SPACES

try:
    from lightgbm import LGBMClassifier, LGBMRegressor
except ImportError:
    LGBMClassifier = None  # type: ignore
    LGBMRegressor = None  # type: ignore

try:
    from xgboost import XGBClassifier
except ImportError:
    XGBClassifier = None  # type: ignore

_CLASSIFICATION_STAGES = {"stage1_tech", "stage2_fdm", "stage2_sla"}

optuna.logging.set_verbosity(optuna.logging.WARNING)


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


def _eval_reg(model, X_val, y_val: pd.DataFrame, stage_name: str) -> float:
    y_pred = pd.DataFrame(model.predict(X_val), columns=y_val.columns)
    ranges = _param_ranges(stage_name)
    mae_pcts = []
    for col in y_val.columns:
        key = col.removeprefix("param_")
        lo, hi = ranges[key]
        mae = mean_absolute_error(y_val[col], y_pred[col])
        mae_pcts.append(mae / (hi - lo) * 100)
    return float(np.mean(mae_pcts))


def tune_stage(
    stage_name: str,
    family: str,
    splits: dict,
    n_trials: int = 50,
    seed: int = 1337,
) -> dict:
    """Run optuna study for given stage + family.

    Objective:
      - Classification: maximize macro F1 on val set
      - Regression: minimize mean MAE % of range on val set

    Returns:
      {
        "stage": stage_name,
        "family": family,
        "best_params": dict,
        "best_value": float,
        "n_trials": n_trials,
      }
    """
    is_clf = stage_name in _CLASSIFICATION_STAGES
    split = splits[stage_name]
    space_fn = (CLASSIFIER_SPACES if is_clf else REGRESSOR_SPACES)[family]

    def objective(trial):
        params = space_fn(trial)
        model = _build_clf(family, params) if is_clf else _build_reg(family, params)
        if is_clf and family == "xgboost":
            y_arr = split.y_train.to_numpy()
            le = LabelEncoder()
            y_enc = le.fit_transform(y_arr)
            sw = compute_sample_weight("balanced", y_enc)
            model.fit(split.X_train, y_enc, sample_weight=sw)
            y_pred_enc = np.asarray(model.predict(split.X_val))
            y_pred = le.inverse_transform(y_pred_enc.astype(int)) if y_pred_enc.dtype != object else y_pred_enc
        else:
            model.fit(split.X_train, split.y_train)
            y_pred = model.predict(split.X_val) if is_clf else None
        if is_clf:
            return float(f1_score(split.y_val, y_pred, average="macro"))
        return _eval_reg(model, split.X_val, split.y_val, stage_name)

    direction = "maximize" if is_clf else "minimize"
    sampler = optuna.samplers.TPESampler(seed=seed)
    study = optuna.create_study(direction=direction, sampler=sampler)
    study.optimize(objective, n_trials=n_trials, timeout=600)

    return {
        "stage": stage_name,
        "family": family,
        "best_params": study.best_params,
        "best_value": float(study.best_value),
        "n_trials": len(study.trials),
    }
