"""Run benchmark with split seed varying across [1337, 42, 0, 7, 2024]."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

import pandas as pd

from ml3dp.benchmark.runner import run_benchmark
from ml3dp.features.prepare import prepare_all_stages

SEEDS = [1337, 42, 0, 7, 2024]
OUT = ROOT / "reports" / "tables" / "03_benchmark_results.csv"


def main() -> None:
    df = pd.read_parquet(ROOT / "data" / "synthetic_v3.parquet")
    all_rows: list[pd.DataFrame] = []
    for seed in SEEDS:
        print(f"[seed={seed}] preparing splits and running benchmark …")
        splits = prepare_all_stages(df, encoder_kind="ordinal", seed=seed)
        res = run_benchmark(splits, seeds=[seed])
        all_rows.append(res)
    results = pd.concat(all_rows, ignore_index=True)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    results.to_csv(OUT, index=False)
    print(f"Saved {len(results)} rows -> {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
