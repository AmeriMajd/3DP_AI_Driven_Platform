"""Per-class F1 breakdown and confusion matrix utilities."""

from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
from sklearn.metrics import confusion_matrix, precision_recall_fscore_support


def per_class_breakdown(
    y_true, y_pred, class_names: list[str]
) -> pd.DataFrame:
    """Returns DataFrame with columns:
       class, support, precision, recall, f1, n_misclassified
    """
    y_true = np.asarray(y_true)
    y_pred = np.asarray(y_pred)

    precision, recall, f1, support = precision_recall_fscore_support(
        y_true, y_pred, labels=class_names, zero_division=0
    )
    n_misclassified = support - np.array(
        [(y_true[y_true == c] == y_pred[y_true == c]).sum() for c in class_names]
    )

    return pd.DataFrame(
        {
            "class": class_names,
            "support": support.astype(int),
            "precision": precision,
            "recall": recall,
            "f1": f1,
            "n_misclassified": n_misclassified.astype(int),
        }
    )


def confusion_matrix_df(
    y_true, y_pred, class_names: list[str]
) -> pd.DataFrame:
    """Returns confusion matrix as DataFrame with class names as index/columns."""
    cm = confusion_matrix(y_true, y_pred, labels=class_names)
    return pd.DataFrame(cm, index=class_names, columns=class_names)


def plot_confusion_matrix(
    cm_df: pd.DataFrame,
    out_path: Path,
    title: str,
    normalize: bool = False,
) -> None:
    """Saves heatmap PNG. When normalize=True, rows are divided by their sum
    (recall-normalized) and values are shown as proportions."""
    sns.set_theme(style="whitegrid")
    if normalize:
        data = cm_df.div(cm_df.sum(axis=1), axis=0)
        fmt = ".2f"
        vmin, vmax = 0.0, 1.0
    else:
        data = cm_df
        fmt = "d"
        vmin, vmax = None, None
    fig, ax = plt.subplots(figsize=(8, 6))
    sns.heatmap(
        data,
        annot=True,
        fmt=fmt,
        cmap="Blues",
        ax=ax,
        linewidths=0.5,
        vmin=vmin,
        vmax=vmax,
    )
    ax.set_title(title)
    ax.set_xlabel("Prédit")
    ax.set_ylabel("Réel")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out_path, dpi=150, bbox_inches="tight")
    plt.close(fig)
