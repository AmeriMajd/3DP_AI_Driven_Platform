"""Diagnostic report aggregator."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.base import clone

from ml3dp.benchmark.candidates import CLASSIFIERS, REGRESSORS
from ml3dp.benchmark.runner import THRESHOLDS, _clone_with_seed, _eval_clf, _fit
from ml3dp.diagnostic.ceiling import estimate_ceiling
from ml3dp.diagnostic.feature_importance import (
    compute_permutation_importance,
    plot_permutation_importances,
)
from ml3dp.diagnostic.per_class import (
    confusion_matrix_df,
    per_class_breakdown,
    plot_confusion_matrix,
)

_CLF_STAGES = {"stage1_tech", "stage2_fdm", "stage2_sla"}

_FAMILY_DISPLAY: dict[str, str] = {
    "xgboost": "XGBoost",
    "random_forest": "Random Forest",
    "lightgbm": "LightGBM",
    "catboost": "CatBoost",
    "logistic_regression": "Régression Logistique",
}

_STAGE_DISPLAY: dict[str, str] = {
    "stage1_tech": "Étape 1",
    "stage2_fdm": "Étape 2 FDM",
    "stage2_sla": "Étape 2 SLA",
    "stage3_fdm": "Étape 3 FDM",
    "stage3_sla": "Étape 3 SLA",
}


def run_diagnostic(
    splits: dict,
    results_df: pd.DataFrame,
    winners_df: pd.DataFrame,
    out_dir: Path,
) -> dict:
    """Aggregator. For each classification stage:
       1. Estimate ceiling
       2. Train winner model fresh on train, predict on val
       3. Per-class breakdown
       4. Confusion matrix + plot
       5. Feature importance + plot
       6. Compare winner_metric vs ceiling, classify failure mode

    Returns summary dict, writes:
       reports/figures/05_confusion_<stage>.png
       reports/figures/05_importance_<stage>.png
       reports/tables/05_per_class_<stage>.csv
       reports/tables/05_diagnostic_summary.csv
       reports/05_diagnostic_report.json
    """
    fig_dir = out_dir / "figures"
    tbl_dir = out_dir / "tables"
    fig_dir.mkdir(parents=True, exist_ok=True)
    tbl_dir.mkdir(parents=True, exist_ok=True)

    # Load raw df for ceiling estimation (val indices preserved in splits)
    raw_df = pd.read_parquet(out_dir.parent / "data" / "synthetic_v3.parquet")

    winners_idx = winners_df.set_index("stage")
    summary_rows: list[dict] = []

    for stage_name, split in splits.items():
        winner_family = winners_idx.loc[stage_name, "winner_family"]
        winner_metric = float(winners_idx.loc[stage_name, "mean_metric"])
        passed = bool(winners_idx.loc[stage_name, "passed"])

        is_clf = stage_name in _CLF_STAGES
        catalog = CLASSIFIERS if is_clf else REGRESSORS

        # Re-train winner fresh
        model = _clone_with_seed(catalog[winner_family], seed=0)
        _fit(model, winner_family, split.X_train, split.y_train)

        stage_label = _STAGE_DISPLAY.get(stage_name, stage_name)
        family_label = _FAMILY_DISPLAY.get(winner_family, winner_family)

        # Permutation feature importance
        perm_imp = compute_permutation_importance(
            model, split.X_val, split.y_val, split.feature_names
        )
        plot_permutation_importances(
            perm_imp,
            fig_dir / f"05_importance_{stage_name}.png",
            title=f"Importances des features par permutation — {stage_label}",
        )

        if is_clf:
            # Predict on val
            y_pred_raw = model.predict(split.X_val)
            le = getattr(model, "_le", None)
            if le is not None:
                y_pred_arr = np.asarray(y_pred_raw)
                if y_pred_arr.dtype != object:
                    y_pred_raw = le.inverse_transform(y_pred_arr.astype(int))

            y_true = split.y_val
            y_pred = y_pred_raw
            class_names = sorted(y_true.unique().tolist())

            # Per-class breakdown
            breakdown = per_class_breakdown(y_true, y_pred, class_names)
            breakdown.to_csv(tbl_dir / f"05_per_class_{stage_name}.csv", index=False)

            # Normalized confusion matrix
            cm = confusion_matrix_df(y_true, y_pred, class_names)
            plot_confusion_matrix(
                cm,
                fig_dir / f"05_confusion_{stage_name}.png",
                title=f"Matrice de confusion normalisée, {stage_label} ({family_label})",
                normalize=True,
            )

            # Ceiling estimation on val set
            val_raw = raw_df.loc[split.X_val.index]
            ceiling_result = estimate_ceiling(val_raw, stage_name)
            ceiling = ceiling_result["agreement_rate"]
            gap = ceiling - winner_metric

            if passed:
                failure_mode = "passed"
            elif gap < 0.02:
                failure_mode = "data_limited"
            else:
                failure_mode = "model_limited"

            summary_rows.append(
                {
                    "stage": stage_name,
                    "winner_family": winner_family,
                    "winner_metric": round(winner_metric, 4),
                    "ceiling": round(ceiling, 4),
                    "gap": round(gap, 4),
                    "failure_mode": failure_mode,
                }
            )
        else:
            # Regression stage — no ceiling
            summary_rows.append(
                {
                    "stage": stage_name,
                    "winner_family": winner_family,
                    "winner_metric": round(winner_metric, 4),
                    "ceiling": float("nan"),
                    "gap": float("nan"),
                    "failure_mode": "n/a",
                }
            )

    summary_df = pd.DataFrame(summary_rows)
    summary_df.to_csv(tbl_dir / "05_diagnostic_summary.csv", index=False)

    summary_dict = summary_df.to_dict(orient="records")
    (out_dir / "05_diagnostic_report.json").write_text(
        json.dumps(summary_dict, indent=2, allow_nan=True)
    )

    return {"summary": summary_dict}
