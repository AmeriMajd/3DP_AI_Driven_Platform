"""Stratified train/val/test splitting utilities."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Sequence

import pandas as pd
from sklearn.model_selection import train_test_split


@dataclass
class StageSplit:
    stage_name: str
    X_train: pd.DataFrame
    X_val: pd.DataFrame
    X_test: pd.DataFrame
    y_train: pd.Series | pd.DataFrame
    y_val: pd.Series | pd.DataFrame
    y_test: pd.Series | pd.DataFrame
    feature_names: list[str]


def make_split(
    df: pd.DataFrame,
    X_cols: Sequence[str],
    y_col_or_cols: str | Sequence[str],
    stratify_col: str | None,
    seed: int = 1337,
) -> StageSplit:
    """Create a deterministic 70/15/15 train/val/test split."""
    indices = df.index.to_numpy()
    stratify_values = df[stratify_col] if stratify_col else None

    train_idx, temp_idx = train_test_split(
        indices,
        test_size=0.30,
        random_state=seed,
        stratify=stratify_values,
    )

    temp_stratify = df.loc[temp_idx, stratify_col] if stratify_col else None
    val_idx, test_idx = train_test_split(
        temp_idx,
        test_size=0.50,
        random_state=seed,
        stratify=temp_stratify,
    )

    X_train = df.loc[train_idx, list(X_cols)]
    X_val = df.loc[val_idx, list(X_cols)]
    X_test = df.loc[test_idx, list(X_cols)]

    if isinstance(y_col_or_cols, str):
        y_train = df.loc[train_idx, y_col_or_cols]
        y_val = df.loc[val_idx, y_col_or_cols]
        y_test = df.loc[test_idx, y_col_or_cols]
    else:
        y_cols = list(y_col_or_cols)
        y_train = df.loc[train_idx, y_cols]
        y_val = df.loc[val_idx, y_cols]
        y_test = df.loc[test_idx, y_cols]

    all_idx = pd.Index(train_idx).append(pd.Index(val_idx)).append(pd.Index(test_idx))
    assert all_idx.is_unique, "Leakage guard failed: duplicated indices across splits."
    assert len(all_idx) == len(df), "Split sizes do not sum to input length."

    return StageSplit(
        stage_name="",
        X_train=X_train,
        X_val=X_val,
        X_test=X_test,
        y_train=y_train,
        y_val=y_val,
        y_test=y_test,
        feature_names=list(X_cols),
    )
