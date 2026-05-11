"""Re-evaluate Optuna-tuned hyperparameters under the corrected 5-seed benchmark protocol.

Comparison fix only — NO re-tuning. Pairs the tuned hyperparameters
(results/optuna_best_params.json) with scores that are directly comparable to the
default-hyperparameter benchmark (results/benchmark_per_seed.csv).

Protocol (identical to scripts/run_benchmark_seeded.py):
  for seed in [1337, 42, 0, 7, 2024]:
      splits = prepare_all_stages(df, encoder_kind="ordinal", seed=seed)   # re-stratifies
      fit the tuned model on the train split
      score on the VALIDATION split (not the test split)
  report mean ± std across the 5 seeds.

Training / evaluation logic is reused from ml3dp.benchmark.runner so this script cannot
drift from the benchmark. Balancing policy matches the corrected benchmark:
  CatBoost            -> auto_class_weights='Balanced'
  LightGBM            -> class_weight='balanced'
  RandomForest (clf)  -> class_weight='balanced'   (not used here; stage3 is regression)
  RandomForest (reg)  -> no balancing
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from sklearn.multioutput import MultiOutputRegressor

try:
    from lightgbm import LGBMClassifier
except ImportError:  # pragma: no cover
    LGBMClassifier = None  # type: ignore
try:
    from catboost import CatBoostClassifier
except ImportError:  # pragma: no cover
    CatBoostClassifier = None  # type: ignore

from ml3dp.features.prepare import prepare_all_stages
from ml3dp.benchmark.runner import (
    _CLASSIFICATION_STAGES,
    _clone_with_seed,
    _eval_clf,
    _eval_reg,
    _fit,
)

SEEDS = [1337, 42, 0, 7, 2024]

# stage -> winning family (the same winners the Optuna run tuned)
WINNERS: dict[str, str] = {
    "stage1_tech": "catboost",
    "stage2_fdm": "lightgbm",
    "stage2_sla": "catboost",
    "stage3_fdm": "random_forest",
    "stage3_sla": "random_forest",
}

RESULTS = ROOT / "results"
BEST_PARAMS_JSON = RESULTS / "optuna_best_params.json"
DEFAULT_PER_SEED = RESULTS / "benchmark_per_seed.csv"
OUT_PER_SEED = RESULTS / "tuned_benchmark_per_seed.csv"
OUT_SUMMARY = RESULTS / "tuned_benchmark_summary.csv"


def _coerce(value):
    """JSON brings integer hyperparameters back as strings ("10", "100"); cast them.

    Real floats, ``None`` and non-numeric strings pass through untouched.
    """
    if isinstance(value, str):
        s = value.strip()
        try:
            return int(s)
        except ValueError:
            pass
        try:
            return float(s)
        except ValueError:
            return value
    return value


def _build_model(family: str, params: dict):
    """Instantiate the winning family with tuned params + the corrected-benchmark balancing."""
    if family == "catboost":
        if CatBoostClassifier is None:
            raise RuntimeError("catboost is not installed")
        return CatBoostClassifier(**params, verbose=0, auto_class_weights="Balanced")
    if family == "lightgbm":
        if LGBMClassifier is None:
            raise RuntimeError("lightgbm is not installed")
        return LGBMClassifier(**params, class_weight="balanced", verbose=-1)
    if family == "random_forest":
        # stage3 — multi-output regression, no class balancing
        return MultiOutputRegressor(RandomForestRegressor(**params))
    raise ValueError(f"Unhandled family: {family}")


def main() -> None:
    df = pd.read_parquet(ROOT / "data" / "synthetic_v3.parquet")

    with open(BEST_PARAMS_JSON) as f:
        raw_params: dict[str, dict] = json.load(f)

    tuned_params: dict[str, dict] = {}
    for stage in WINNERS:
        if stage not in raw_params:
            sys.exit(f"ERROR: {stage} missing from {BEST_PARAMS_JSON.name}")
        tuned_params[stage] = {k: _coerce(v) for k, v in raw_params[stage].items()}

    # --- fail fast on a bad / unsupported hyperparameter --------------------
    for stage, family in WINNERS.items():
        try:
            _build_model(family, tuned_params[stage])
        except TypeError as exc:
            sys.exit(
                f"ERROR: {stage}/{family} rejected a tuned hyperparameter: {exc}\n"
                f"       params = {tuned_params[stage]}"
            )

    print("Tuned hyperparameters (cast):")
    for stage, family in WINNERS.items():
        print(f"  {stage:<14} {family:<14} {tuned_params[stage]}")

    # --- 5-seed loop -------------------------------------------------------
    records: dict[str, dict[int, float]] = {s: {} for s in WINNERS}
    for seed in SEEDS:
        print(f"\n[seed={seed}] preparing splits and fitting tuned models ...")
        splits = prepare_all_stages(df, encoder_kind="ordinal", seed=seed)
        for stage, family in WINNERS.items():
            split = splits[stage]
            model = _clone_with_seed(_build_model(family, tuned_params[stage]), seed)
            try:
                _fit(model, family, split.X_train, split.y_train)
            except Exception as exc:  # a bad param that only bites at fit time
                sys.exit(
                    f"ERROR: {stage}/{family} failed to fit with tuned params "
                    f"{tuned_params[stage]}: {exc}"
                )
            if stage in _CLASSIFICATION_STAGES:
                f1, _acc = _eval_clf(model, split.X_val, split.y_val)
                score = f1
            else:
                mean_mae_pct, _ = _eval_reg(model, split.X_val, split.y_val, stage)
                score = mean_mae_pct
            records[stage][seed] = score
            print(f"  {stage:<14} {family:<14} {score:.6f}")

    # --- per-seed wide table (mirrors benchmark_per_seed.csv) --------------
    seed_cols = [f"seed_{s}" for s in SEEDS]
    per_seed_rows = []
    for stage, family in WINNERS.items():
        row: dict = {"step": stage, "model": family}
        for s in SEEDS:
            row[f"seed_{s}"] = records[stage][s]
        per_seed_rows.append(row)
    per_seed_df = pd.DataFrame(per_seed_rows, columns=["step", "model"] + seed_cols)
    per_seed_df.to_csv(OUT_PER_SEED, index=False)
    print(f"\nWrote {OUT_PER_SEED.relative_to(ROOT)}")

    # --- summary -----------------------------------------------------------
    summary_rows = []
    for stage, family in WINNERS.items():
        vals = np.array([records[stage][s] for s in SEEDS], dtype=float)
        summary_rows.append(
            {
                "step": stage,
                "model": family,
                "mean_score": float(vals.mean()),
                "std_score": float(vals.std(ddof=1)),
            }
        )
    summary_df = pd.DataFrame(summary_rows, columns=["step", "model", "mean_score", "std_score"])
    summary_df.to_csv(OUT_SUMMARY, index=False)
    print(f"Wrote {OUT_SUMMARY.relative_to(ROOT)}")

    # --- head-to-head vs default benchmark ---------------------------------
    default_wide = pd.read_csv(DEFAULT_PER_SEED)
    print("\n=== Head-to-head: tuned vs default (same 5-seed validation protocol) ===")
    print("  metric: stage1/2 = macro-F1 (higher = better) | stage3 = MAE % of range (lower = better)")
    print(
        f"  {'step':<14} {'model':<14} {'default_mean +/- std':<24} "
        f"{'tuned_mean +/- std':<24} {'delta (tuned - default)':>24}"
    )
    for stage, family in WINNERS.items():
        d_row = default_wide[(default_wide["step"] == stage) & (default_wide["model"] == family)]
        if d_row.empty:
            print(f"  {stage:<14} {family:<14} (no default row in {DEFAULT_PER_SEED.name})")
            continue
        d_vals = d_row[seed_cols].to_numpy(dtype=float).ravel()
        d_mean, d_std = d_vals.mean(), d_vals.std(ddof=1)
        t_vals = np.array([records[stage][s] for s in SEEDS], dtype=float)
        t_mean, t_std = t_vals.mean(), t_vals.std(ddof=1)
        delta = t_mean - d_mean
        if stage in _CLASSIFICATION_STAGES:
            verdict = "better" if delta > 0 else ("same" if delta == 0 else "worse")
        else:
            verdict = "better" if delta < 0 else ("same" if delta == 0 else "worse")
        print(
            f"  {stage:<14} {family:<14} {d_mean:.4f} +/- {d_std:.4f}          "
            f"{t_mean:.4f} +/- {t_std:.4f}          {delta:+.4f}  ({verdict})"
        )


if __name__ == "__main__":
    main()
