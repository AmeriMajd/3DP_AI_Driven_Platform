"""
Usage: python scripts/04_run_diagnostic.py
"""

from __future__ import annotations

import sys
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from ml3dp.diagnostic.report import run_diagnostic
from ml3dp.features.prepare import prepare_all_stages

DATA_PATH = ROOT / "data" / "synthetic_v3.parquet"
RESULTS_PATH = ROOT / "reports" / "tables" / "03_benchmark_results.csv"
WINNERS_PATH = ROOT / "reports" / "tables" / "03_winners.csv"
OUT_DIR = ROOT / "reports"


def main() -> None:
    df = pd.read_parquet(DATA_PATH)
    splits = prepare_all_stages(df)
    results_df = pd.read_csv(RESULTS_PATH)
    winners_df = pd.read_csv(WINNERS_PATH)

    result = run_diagnostic(splits, results_df, winners_df, out_dir=OUT_DIR)

    summary = pd.DataFrame(result["summary"])
    print(summary.to_string(index=False))


if __name__ == "__main__":
    main()
