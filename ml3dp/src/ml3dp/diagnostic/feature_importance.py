"""Per-stage feature importance extraction and plotting."""

from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
from sklearn.inspection import permutation_importance as sk_permutation_importance


# ─── Model-based importances (kept for reference) ─────────────────────────────

def extract_importances(model, feature_names: list[str]) -> pd.DataFrame:
    """Returns DataFrame: feature, importance, rank (model-based)."""
    importances = _get_importances(model, len(feature_names))
    df = pd.DataFrame({"feature": feature_names, "importance": importances})
    df = df.sort_values("importance", ascending=False).reset_index(drop=True)
    df["rank"] = range(1, len(df) + 1)
    return df


# ─── Permutation importances ──────────────────────────────────────────────────

class _LEWrapper:
    """Wraps XGBoost + LabelEncoder so predict/score use original string labels."""

    def __init__(self, model, le):
        self._model = model
        self._le = le

    def fit(self, X, y=None):
        return self

    def predict(self, X):
        raw = np.asarray(self._model.predict(X))
        if raw.dtype != object:
            return self._le.inverse_transform(raw.astype(int))
        return raw

    def score(self, X, y):
        from sklearn.metrics import accuracy_score
        return accuracy_score(y, self.predict(X))


def compute_permutation_importance(
    model,
    X_val,
    y_val,
    feature_names: list[str],
    n_repeats: int = 10,
    random_state: int = 0,
) -> pd.DataFrame:
    """Compute permutation importances on a validation set.

    Handles XGBoost models that store a LabelEncoder in model._le.
    Returns DataFrame: feature, importance (mean), std, rank.
    """
    le = getattr(model, "_le", None)
    scorer = _LEWrapper(model, le) if le is not None else model

    result = sk_permutation_importance(
        scorer,
        X_val,
        y_val,
        n_repeats=n_repeats,
        random_state=random_state,
    )
    df = pd.DataFrame({
        "feature": feature_names,
        "importance": result.importances_mean,
        "std": result.importances_std,
    })
    df = df.sort_values("importance", ascending=False).reset_index(drop=True)
    df["rank"] = range(1, len(df) + 1)
    return df


def plot_permutation_importances(
    importances_df: pd.DataFrame,
    out_path: Path,
    title: str,
    top_n: int = 15,
) -> None:
    """Horizontal bar chart with error bars for permutation importances."""
    sns.set_theme(style="whitegrid")
    subset = importances_df.head(top_n).iloc[::-1]
    fig, ax = plt.subplots(figsize=(10, 8))
    palette = sns.color_palette("colorblind", n_colors=len(subset))
    ax.barh(
        subset["feature"],
        subset["importance"],
        xerr=subset["std"],
        color=palette,
        capsize=3,
    )
    ax.set_title(title)
    ax.set_xlabel("Diminution de performance (permutation)")
    ax.set_ylabel("Feature")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out_path, dpi=150, bbox_inches="tight")
    plt.close(fig)


# ─── Kept for backward compat (model-based bar chart) ─────────────────────────

def plot_importances(
    importances_df: pd.DataFrame,
    out_path: Path,
    title: str,
    top_n: int = 15,
) -> None:
    """Horizontal bar chart, top_n features (model-based)."""
    sns.set_theme(style="whitegrid")
    subset = importances_df.head(top_n).iloc[::-1]
    fig, ax = plt.subplots(figsize=(10, 8))
    palette = sns.color_palette("colorblind", n_colors=len(subset))
    sns.barplot(data=subset, x="importance", y="feature", palette=palette, ax=ax)
    ax.set_title(title)
    ax.set_xlabel("Importance")
    ax.set_ylabel("Feature")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out_path, dpi=150, bbox_inches="tight")
    plt.close(fig)


# ─── Internal helpers ─────────────────────────────────────────────────────────

def _get_importances(model, n_features: int) -> np.ndarray:
    if hasattr(model, "estimators_"):
        parts = [_extract_single(est, n_features) for est in model.estimators_]
        return np.mean(parts, axis=0)
    return _extract_single(model, n_features)


def _extract_single(model, n_features: int) -> np.ndarray:
    if hasattr(model, "named_steps"):
        inner = list(model.named_steps.values())[-1]
        return _extract_single(inner, n_features)

    if hasattr(model, "feature_importances_"):
        return np.asarray(model.feature_importances_, dtype=float)

    if hasattr(model, "coef_"):
        coef = np.asarray(model.coef_, dtype=float)
        if coef.ndim > 1:
            return np.abs(coef).mean(axis=0)
        return np.abs(coef)

    return np.ones(n_features, dtype=float) / n_features
