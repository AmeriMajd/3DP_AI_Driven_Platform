"""
Step 4+5: Final evaluation on test set and save deployment-ready models.

Usage:
    python scripts/07_final_evaluation.py
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

import pandas as pd

from ml3dp.evaluation.final import THRESHOLDS, train_final_models
from ml3dp.features.prepare import prepare_all_stages


def main() -> None:
    df = pd.read_parquet(ROOT / "data" / "synthetic_v3.parquet")
    splits = prepare_all_stages(df)

    tuned_df = pd.read_csv(ROOT / "reports" / "tables" / "06_tuned_params.csv")
    tuned_params = {}
    for _, row in tuned_df.iterrows():
        tuned_params[row["stage"]] = {
            "family": row["family"],
            "best_params": json.loads(row["best_params"]),
        }

    out_dir = ROOT / "models_ml"
    print("Training final models on train+val, evaluating on test …")
    summary = train_final_models(splits, tuned_params, out_dir=out_dir)

    tables_dir = ROOT / "reports" / "tables"
    tables_dir.mkdir(parents=True, exist_ok=True)
    summary.to_csv(tables_dir / "07_final_test_results.csv", index=False)

    report = {
        "dataset": {"path": str(ROOT / "data" / "synthetic_v3.parquet"), "n_rows": len(df)},
        "stages": [],
    }
    for _, row in summary.iterrows():
        report["stages"].append({
            "stage": row["stage"],
            "family": row["family"],
            "test_metric_primary": row["test_metric_primary"],
            "test_metric_secondary": row["test_metric_secondary"],
            "passed_threshold": bool(row["passed_threshold"]),
            "threshold": THRESHOLDS[row["stage"]],
            "model_path": row["model_path"],
        })

    report_path = ROOT / "reports" / "07_final_report.json"
    report_path.write_text(json.dumps(report, indent=2))

    print("\n=== Final test results ===")
    for _, row in summary.iterrows():
        status = "PASS" if row["passed_threshold"] else "FAIL"
        print(
            f"  {row['stage']:<14}  {row['family']:<22}"
            f"  primary={row['test_metric_primary']:.4f}"
            f"  secondary={row['test_metric_secondary']:.4f}"
            f"  [{status}]"
        )
    print(f"\nSaved -> reports/tables/07_final_test_results.csv")
    print(f"Saved -> reports/07_final_report.json")
    print(f"Models -> {out_dir}")
    print()
    print(summary.to_string(index=False))


if __name__ == "__main__":
    main()
