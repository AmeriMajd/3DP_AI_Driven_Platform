"""Bayes-optimal ceiling estimation via rule re-application."""

from __future__ import annotations

import pandas as pd

from ml3dp.data import rules

_CLASSIFICATION_STAGES = {"stage1_tech", "stage2_fdm", "stage2_sla"}


def estimate_ceiling(df: pd.DataFrame, stage: str) -> dict:
    """Compute empirical Bayes-optimal F1 for a classification stage.

    For each row in df:
      - Re-apply the rule from ml3dp.data.rules to clean inputs
      - Compare rule output to stored label

    Returns:
      {
        "stage": stage,
        "n_rows": int,
        "agreement_rate": float,   # = ceiling estimate
        "n_disagreements": int,
        "noise_estimate": float,   # = 1 - agreement_rate
      }

    Stage values: "stage1_tech", "stage2_fdm", "stage2_sla"
    """
    if stage not in _CLASSIFICATION_STAGES:
        raise ValueError(f"stage must be one of {_CLASSIFICATION_STAGES}, got {stage!r}")

    if stage == "stage1_tech":
        subset = df
        rule_fn = rules.technology_for
        label_col = "technology"
    elif stage == "stage2_fdm":
        subset = df[df["technology"] == "FDM"]
        rule_fn = rules.fdm_material_for
        label_col = "material"
    else:  # stage2_sla
        subset = df[df["technology"] == "SLA"]
        rule_fn = rules.sla_material_for
        label_col = "material"

    n = len(subset)
    disagreements = sum(
        rule_fn(row) != row[label_col]
        for row in subset.to_dict(orient="records")
    )

    agreement_rate = (n - disagreements) / n if n > 0 else 0.0
    return {
        "stage": stage,
        "n_rows": n,
        "agreement_rate": agreement_rate,
        "n_disagreements": disagreements,
        "noise_estimate": 1.0 - agreement_rate,
    }
