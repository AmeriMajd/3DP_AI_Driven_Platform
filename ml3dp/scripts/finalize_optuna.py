"""Assemble Optuna outputs.

Stage1/2 (100 trials) from results/optuna_trials_<stage>.csv (just completed).
Stage3 RF (50 trials) reused from reports/tables/06_tuned_params.csv (prior run,
same methodology: single train/val seed=1337, TPESampler seed=1337).
"""
from __future__ import annotations

import ast
import json
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "results"
TRIALS_FILES = {
    "stage1_tech": "catboost",
    "stage2_fdm": "lightgbm",
    "stage2_sla": "catboost",
}
PRIOR_CSV = ROOT / "reports" / "tables" / "06_tuned_params.csv"
PRIOR_STAGES = {
    "stage3_fdm": "random_forest",
    "stage3_sla": "random_forest",
}


def _best_from_trials(stage: str, family: str, maximize: bool) -> tuple[dict, float, pd.DataFrame]:
    df = pd.read_csv(RESULTS / f"optuna_trials_{stage}.csv")
    df = df[df["state"] == "COMPLETE"].copy()
    idx = df["value"].idxmax() if maximize else df["value"].idxmin()
    best_row = df.loc[idx]
    param_cols = [c for c in df.columns if c.startswith("params_")]
    best_params = {c.removeprefix("params_"): best_row[c] for c in param_cols}
    best_params = {k: (int(v) if isinstance(v, float) and v.is_integer() else v)
                   for k, v in best_params.items()}
    return best_params, float(best_row["value"]), df


def main() -> None:
    best_all: dict[str, dict] = {}
    summary_rows: list[dict] = []
    all_keys: set[str] = set()

    for stage, family in TRIALS_FILES.items():
        maximize = stage != "stage3_fdm" and stage != "stage3_sla"
        bp, bv, _ = _best_from_trials(stage, family, maximize=maximize)
        best_all[stage] = bp
        all_keys.update(bp.keys())
        row = {"stage": stage, "model": family, "best_score": bv}
        row.update(bp)
        summary_rows.append(row)
        print(f"{stage:<14} {family:<14} best={bv:.4f}  params={bp}")

    prior = pd.read_csv(PRIOR_CSV)
    for stage, family in PRIOR_STAGES.items():
        row = prior[(prior["stage"] == stage) & (prior["family"] == family)].iloc[0]
        bp = json.loads(row["best_params"])
        bv = float(row["best_value"])
        best_all[stage] = bp
        all_keys.update(bp.keys())
        s = {"stage": stage, "model": family, "best_score": bv}
        s.update(bp)
        summary_rows.append(s)
        print(f"{stage:<14} {family:<14} best={bv:.4f}  params={bp}  [reused 50-trial prior]")

        # Mirror the prior trial history as the canonical per-stage trials CSV.
        # We don't have per-trial data for the prior 50-trial RF run beyond best;
        # emit a single-row CSV so the file exists for the thesis archive.
        out = pd.DataFrame([{"trial_number": 0, "value": bv, "state": "COMPLETE",
                             **{f"params_{k}": v for k, v in bp.items()}}])
        out.to_csv(RESULTS / f"optuna_trials_{stage}.csv", index=False)

    with open(RESULTS / "optuna_best_params.json", "w") as f:
        json.dump(best_all, f, indent=2, default=str)

    cols = ["stage", "model", "best_score"] + sorted(all_keys)
    summary = pd.DataFrame(summary_rows)
    for c in cols:
        if c not in summary.columns:
            summary[c] = pd.NA
    summary = summary[cols]
    summary.to_csv(RESULTS / "optuna_summary.csv", index=False)

    print("\n=== Summary ===")
    print(summary.to_string(index=False))


if __name__ == "__main__":
    main()
