"""
Usage:
    python scripts/03_run_benchmark.py [--encoder ordinal|onehot] [--smoke]

--smoke: 1 seed, 2 families (logistic_regression + random_forest).
         Use for fast verification before the full 125-run benchmark.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

import pandas as pd

from ml3dp.benchmark.runner import THRESHOLDS, run_benchmark, select_winners
from ml3dp.features.prepare import prepare_all_stages


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--encoder", default="ordinal", choices=["ordinal", "onehot"])
    parser.add_argument("--smoke", action="store_true")
    args = parser.parse_args()

    df = pd.read_parquet(ROOT / "data" / "synthetic_v3.parquet")
    splits = prepare_all_stages(df, encoder_kind=args.encoder)

    print(f"Running benchmark (smoke={args.smoke}, encoder={args.encoder}) …")
    results = run_benchmark(splits, encoder_kind=args.encoder, smoke=args.smoke)

    out_dir = ROOT / "reports" / "tables"
    out_dir.mkdir(parents=True, exist_ok=True)

    results.to_csv(out_dir / "03_benchmark_results.csv", index=False)
    print(f"Saved {len(results)} rows -> reports/tables/03_benchmark_results.csv")

    winners = select_winners(results)

    winner_rows = []
    for stage, family in winners.items():
        mask = (results["stage"] == stage) & (results["family"] == family)
        sub = results.loc[mask, "metric_primary"]
        mean_m = sub.mean()
        std_m = sub.std(ddof=1) if len(sub) > 1 else 0.0
        is_reg = "stage3" in stage
        passed = bool(mean_m <= THRESHOLDS[stage]) if is_reg else bool(mean_m >= THRESHOLDS[stage])
        winner_rows.append(
            {
                "stage": stage,
                "winner_family": family,
                "mean_metric": mean_m,
                "std_metric": std_m,
                "passed": passed,
            }
        )

    winners_df = pd.DataFrame(winner_rows)
    winners_df.to_csv(out_dir / "03_winners.csv", index=False)

    print("\n-- Per-stage winners ------------------------------------------")
    for _, row in winners_df.iterrows():
        direction = "v MAE%" if "stage3" in row["stage"] else "^ F1  "
        status = "PASS" if row["passed"] else "FAIL"
        print(
            f"  {row['stage']:<14}  {row['winner_family']:<22}"
            f"  {direction} {row['mean_metric']:.4f} ± {row['std_metric']:.4f}"
            f"  [{status}]"
        )
    print()


if __name__ == "__main__":
    main()
