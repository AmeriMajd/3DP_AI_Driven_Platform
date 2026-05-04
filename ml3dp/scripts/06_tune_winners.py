"""
Step 3: Hyperparameter tuning for each stage's winner family.

Usage:
    python scripts/06_tune_winners.py [--n-trials 50]
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

import pandas as pd

from ml3dp.features.prepare import prepare_all_stages
from ml3dp.tuning.optimizer import tune_stage


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--n-trials", type=int, default=50)
    args = parser.parse_args()

    df = pd.read_parquet(ROOT / "data" / "synthetic_v3.parquet")
    splits = prepare_all_stages(df)

    winners = pd.read_csv(ROOT / "reports" / "tables" / "03_winners.csv")
    out_dir = ROOT / "reports" / "tables"
    out_dir.mkdir(parents=True, exist_ok=True)

    rows = []
    for _, row in winners.iterrows():
        stage = row["stage"]
        family = row["winner_family"]
        print(f"Tuning {stage} / {family} ({args.n_trials} trials) …")
        result = tune_stage(stage, family, splits, n_trials=args.n_trials)
        rows.append({
            "stage": stage,
            "family": family,
            "best_value": result["best_value"],
            "best_params": json.dumps(result["best_params"]),
        })
        print(f"  best_value={result['best_value']:.4f}  params={result['best_params']}")

    tuned_df = pd.DataFrame(rows)
    tuned_df.to_csv(out_dir / "06_tuned_params.csv", index=False)
    print(f"\nSaved -> reports/tables/06_tuned_params.csv")
    print(tuned_df.to_string(index=False))


if __name__ == "__main__":
    main()
