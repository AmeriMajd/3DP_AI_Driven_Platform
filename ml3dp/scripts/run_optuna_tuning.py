"""Optuna tuning for 5 new winners.

Methodology aligned with existing project code (ml3dp.tuning.optimizer):
- Single train/val split via prepare_all_stages(df) with default seed=1337
- Objective: maximize Macro F1 on val (classifiers) / minimize MAE % on val (regressors)
- TPESampler(seed=1337)
- Class balancing per family (RF balanced, LightGBM balanced, CatBoost auto, XGBoost sw)
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

import pandas as pd

from ml3dp.features.prepare import prepare_all_stages
from ml3dp.tuning.optimizer import tune_stage

NEW_WINNERS = {
    "stage1_tech": "catboost",
    "stage2_fdm": "lightgbm",
    "stage2_sla": "catboost",
    "stage3_fdm": "random_forest",
    "stage3_sla": "random_forest",
}

N_TRIALS = 100
SEED = 1337
OUT_DIR = ROOT / "results"
OUT_DIR.mkdir(parents=True, exist_ok=True)


def main() -> None:
    df = pd.read_parquet(ROOT / "data" / "synthetic_v3.parquet")
    splits = prepare_all_stages(df, seed=SEED)

    best_params_all: dict[str, dict] = {}
    summary_rows: list[dict] = []
    all_param_keys: set[str] = set()

    for stage, family in NEW_WINNERS.items():
        print(f"\n=== Tuning {stage} / {family} ({N_TRIALS} trials) ===")
        result = tune_stage(stage, family, splits, n_trials=N_TRIALS, seed=SEED)
        bp = result["best_params"]
        bv = result["best_value"]
        print(f"  best_value = {bv:.4f}")
        print(f"  best_params = {bp}")

        best_params_all[stage] = bp
        all_param_keys.update(bp.keys())

        trials_df = result["trials_df"]
        trials_path = OUT_DIR / f"optuna_trials_{stage}.csv"
        trials_df.to_csv(trials_path, index=False)
        print(f"  wrote {trials_path.relative_to(ROOT)}")

        row = {"stage": stage, "model": family, "best_score": bv}
        row.update(bp)
        summary_rows.append(row)

    with open(OUT_DIR / "optuna_best_params.json", "w") as f:
        json.dump(best_params_all, f, indent=2, default=str)
    print(f"\nWrote {(OUT_DIR / 'optuna_best_params.json').relative_to(ROOT)}")

    cols = ["stage", "model", "best_score"] + sorted(all_param_keys)
    summary_df = pd.DataFrame(summary_rows)
    for col in cols:
        if col not in summary_df.columns:
            summary_df[col] = pd.NA
    summary_df = summary_df[cols]
    summary_path = OUT_DIR / "optuna_summary.csv"
    summary_df.to_csv(summary_path, index=False)
    print(f"Wrote {summary_path.relative_to(ROOT)}")

    print("\n=== Summary ===")
    print(summary_df.to_string(index=False))


if __name__ == "__main__":
    main()
