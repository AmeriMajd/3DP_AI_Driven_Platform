"""Benchmark loop: 5 families × 5 seeds across all stages."""

from __future__ import annotations

import numpy as np
import pandas as pd
from sklearn.base import clone
from sklearn.metrics import accuracy_score, f1_score, mean_absolute_error
from sklearn.preprocessing import LabelEncoder
from sklearn.utils.class_weight import compute_sample_weight

from ml3dp.data.schema import FDM_PARAM_RANGES, SLA_PARAM_RANGES
from ml3dp.benchmark.candidates import CLASSIFIERS, FAMILY_PRIORITY, REGRESSORS

THRESHOLDS: dict[str, float] = {
    "stage1_tech": 0.90,
    "stage2_fdm": 0.85,
    "stage2_sla": 0.85,
    "stage3_fdm": 10.0,
    "stage3_sla": 10.0,
}

_CLASSIFICATION_STAGES = {"stage1_tech", "stage2_fdm", "stage2_sla"}
_SMOKE_FAMILIES = ["logistic_regression", "random_forest"]


def _clone_with_seed(model, seed: int):
    m = clone(model)
    for kwarg in ("random_state", "estimator__random_state"):
        try:
            m.set_params(**{kwarg: seed})
            break
        except (ValueError, TypeError):
            pass
    return m


def _fit(model, family: str, X_train, y_train):
    if family == "xgboost":
        # XGBoost requires integer labels; always encode when labels are strings
        y_arr = y_train.to_numpy() if isinstance(y_train, pd.Series) else np.asarray(y_train)
        if y_arr.dtype == object:
            le = LabelEncoder()
            y_enc = le.fit_transform(y_arr)
        else:
            le = None
            y_enc = y_arr
        model._le = le
        sw = compute_sample_weight("balanced", y_enc)
        model.fit(X_train, y_enc, sample_weight=sw)
    else:
        model.fit(X_train, y_train)


def _eval_clf(model, X_val, y_val) -> tuple[float, float]:
    y_pred = model.predict(X_val)
    le = getattr(model, "_le", None)
    if le is not None:
        y_pred_arr = np.asarray(y_pred)
        if y_pred_arr.dtype != object:
            # XGBoost <2.0: integer predictions — decode back to label strings
            y_pred = le.inverse_transform(y_pred_arr.astype(int))
        # XGBoost >=2.0 already returns string labels; pass through
    f1 = f1_score(y_val, y_pred, average="macro")
    acc = accuracy_score(y_val, y_pred)
    return f1, acc


def _param_ranges(stage_name: str) -> dict[str, tuple[float, float]]:
    return FDM_PARAM_RANGES if "fdm" in stage_name else SLA_PARAM_RANGES


def _eval_reg(model, X_val, y_val: pd.DataFrame, stage_name: str) -> tuple[float, dict]:
    y_pred = pd.DataFrame(model.predict(X_val), columns=y_val.columns)
    ranges = _param_ranges(stage_name)
    mae_pct: dict[str, float] = {}
    for col in y_val.columns:
        key = col.removeprefix("param_")
        lo, hi = ranges[key]
        mae = mean_absolute_error(y_val[col], y_pred[col])
        mae_pct[f"mae_pct_{key}"] = mae / (hi - lo) * 100
    return float(np.mean(list(mae_pct.values()))), mae_pct


def run_benchmark(
    splits: dict,
    encoder_kind: str = "ordinal",
    smoke: bool = False,
) -> pd.DataFrame:
    """Run cross-family benchmark.

    Returns a DataFrame with one row per (stage, family, seed) run.
    """
    seeds = [0] if smoke else [0, 1, 2, 3, 4]
    smoke_families = set(_SMOKE_FAMILIES)
    rows: list[dict] = []

    for stage_name, split in splits.items():
        is_clf = stage_name in _CLASSIFICATION_STAGES
        catalog = CLASSIFIERS if is_clf else REGRESSORS

        for family, base_model in catalog.items():
            if smoke and family not in smoke_families:
                continue

            for seed in seeds:
                model = _clone_with_seed(base_model, seed)
                _fit(model, family, split.X_train, split.y_train)

                row: dict = {"stage": stage_name, "family": family, "seed": seed}

                if is_clf:
                    f1, acc = _eval_clf(model, split.X_val, split.y_val)
                    row["metric_primary"] = f1
                    row["metric_secondary"] = acc
                    threshold = THRESHOLDS[stage_name]
                    row["passed_threshold"] = bool(f1 >= threshold)
                else:
                    mean_mae_pct, mae_pct_cols = _eval_reg(
                        model, split.X_val, split.y_val, stage_name
                    )
                    row["metric_primary"] = mean_mae_pct
                    row["metric_secondary"] = float("nan")
                    row.update(mae_pct_cols)
                    threshold = THRESHOLDS[stage_name]
                    row["passed_threshold"] = bool(mean_mae_pct <= threshold)

                rows.append(row)

    return pd.DataFrame(rows)


def select_winners(results_df: pd.DataFrame) -> dict[str, str]:
    """Return {stage_name: family_name} — one winner per stage."""
    winners: dict[str, str] = {}

    for stage in results_df["stage"].unique():
        stage_df = results_df[results_df["stage"] == stage]
        is_regression = stage not in _CLASSIFICATION_STAGES

        stats = (
            stage_df.groupby("family")["metric_primary"]
            .agg(["mean", "std"])
            .reset_index()
        )
        stats["std"] = stats["std"].fillna(0.0)

        if is_regression:
            best_row = stats.loc[stats["mean"].idxmin()]
        else:
            best_row = stats.loc[stats["mean"].idxmax()]

        b_lo = best_row["mean"] - best_row["std"]
        b_hi = best_row["mean"] + best_row["std"]

        overlapping = [
            row["family"]
            for _, row in stats.iterrows()
            if (row["mean"] - row["std"]) <= b_hi
            and (row["mean"] + row["std"]) >= b_lo
        ]

        def _priority(f: str) -> int:
            try:
                return FAMILY_PRIORITY.index(f)
            except ValueError:
                return 99

        winners[stage] = min(overlapping, key=_priority)

    return winners
