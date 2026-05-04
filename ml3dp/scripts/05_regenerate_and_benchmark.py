"""
Step 1+2: Regenerate dataset with reduced noise, then re-run benchmark.

Usage:
    python scripts/05_regenerate_and_benchmark.py
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def run(cmd: list[str]) -> None:
    subprocess.run(cmd, check=True)


def main() -> None:
    python = sys.executable

    print("=== Step 1: Regenerate dataset (reduced noise) ===")
    run([
        python, str(ROOT / "scripts" / "01_generate_dataset.py"),
        "--noise", "0.10",
        "--param-noise", "0.10",
        "--feature-noise", "0.05",
        "--tech-noise", "0.08",
    ])

    print("\n=== Step 2: Run benchmark ===")
    run([python, str(ROOT / "scripts" / "03_run_benchmark.py")])

    print("\n=== Pass/Fail per stage ===")
    import pandas as pd
    winners = pd.read_csv(ROOT / "reports" / "tables" / "03_winners.csv")
    for _, row in winners.iterrows():
        status = "PASS" if row["passed"] else "FAIL"
        print(f"  {row['stage']:<14}  {row['winner_family']:<22}  [{status}]")


if __name__ == "__main__":
    main()
