"""
tests/test_session2.py

Verification tests for the Session 2 EDA deliverable.

Run with:
    python -m pytest tests/test_session2.py -v

Or standalone:
    python tests/test_session2.py

Assumes Session 1 artifact data/synthetic_v3.parquet already exists.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts"
REPORTS = ROOT / "reports"
FIGS = REPORTS / "figures"
TABLES = REPORTS / "tables"

EXPECTED_FIGS = [
    "02_class_distribution.png",
    "02_feature_distributions_by_tech.png",
    "02_separability_matrix.png",
    "02_correlation_heatmap.png",
    "02_intent_material_crosstab.png",
    "02_geometry_by_material_boxplots.png",
    "02_parameter_distributions_by_material.png",
]

EXPECTED_TABLES = [
    "02_class_balance.csv",
    "02_feature_summary.csv",
    "02_separability_matrix.csv",
]

EXPECTED_JSON = [
    "02_eda_summary.json",
    "02_figure_captions.fr.json",
]


# ─── 1. Run the script ────────────────────────────────────────────────────────

def test_script_runs() -> None:
    result = subprocess.run(
        [sys.executable, str(SCRIPTS / "02_run_eda.py")],
        capture_output=True, text=True,
    )
    assert result.returncode == 0, (
        f"02_run_eda.py exited with code {result.returncode}\n"
        f"stdout:\n{result.stdout}\n"
        f"stderr:\n{result.stderr}"
    )


# ─── 2. All expected files exist and are non-empty ────────────────────────────

def test_figures_exist() -> None:
    for name in EXPECTED_FIGS:
        p = FIGS / name
        assert p.exists(), f"Missing figure: {p}"
        assert p.stat().st_size > 0, f"Empty figure: {p}"


def test_tables_exist() -> None:
    for name in EXPECTED_TABLES:
        p = TABLES / name
        assert p.exists(), f"Missing table: {p}"
        assert p.stat().st_size > 0, f"Empty table: {p}"


def test_json_files_exist() -> None:
    for name in EXPECTED_JSON:
        p = REPORTS / name
        assert p.exists(), f"Missing JSON: {p}"
        assert p.stat().st_size > 0, f"Empty JSON: {p}"


# ─── 3. Summary JSON content ─────────────────────────────────────────────────

def test_summary_json_content() -> None:
    with open(REPORTS / "02_eda_summary.json", encoding="utf-8") as f:
        summary = json.load(f)

    assert len(summary["figures"]) == 7, (
        f"Expected 7 figures in summary, got {len(summary['figures'])}"
    )

    hm = summary["headline_metrics"]
    assert hm["max_fdm_pairwise_overlap"] == 0.0, (
        f"FDM overlap should be 0.0, got {hm['max_fdm_pairwise_overlap']}"
    )
    assert hm["max_sla_pairwise_overlap"] == 0.0, (
        f"SLA overlap should be 0.0, got {hm['max_sla_pairwise_overlap']}"
    )


# ─── 4. Class balance CSV content ────────────────────────────────────────────

def test_class_balance_rows() -> None:
    import pandas as pd
    df = pd.read_csv(TABLES / "02_class_balance.csv")
    assert len(df) >= 8, (
        f"class_balance.csv should have ≥8 rows (2 tech + 4 FDM + 2 SLA), "
        f"got {len(df)}"
    )


# ─── Standalone runner ────────────────────────────────────────────────────────

def _run_all() -> None:
    tests = [
        test_script_runs,
        test_figures_exist,
        test_tables_exist,
        test_json_files_exist,
        test_summary_json_content,
        test_class_balance_rows,
    ]
    failed = 0
    for t in tests:
        name = t.__name__
        try:
            t()
            print(f"PASS  {name}")
        except AssertionError as e:
            failed += 1
            print(f"FAIL  {name}\n      {e}")
        except Exception as e:
            failed += 1
            print(f"ERROR {name}\n      {type(e).__name__}: {e}")
    print(f"\n{len(tests) - failed} / {len(tests)} passed")
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    _run_all()
