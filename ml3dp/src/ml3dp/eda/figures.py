"""ml3dp.eda.figures — seven EDA plotting functions for the synthetic dataset."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import matplotlib as mpl
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
from matplotlib.patches import Patch

from ml3dp.data.schema import (
    ALL_FEATURES,
    FDM_MATERIALS,
    FDM_PARAM_NAMES,
    GEOMETRY_FEATURES,
    INTENT_FEATURES,
    SLA_MATERIALS,
    SLA_PARAM_NAMES,
)

# ─── Palettes (consistent across all figures) ─────────────────────────────────

_PAL = sns.color_palette("colorblind")
TECH_PAL: dict[str, Any] = {"FDM": _PAL[0], "SLA": _PAL[1]}
FDM_PAL: dict[str, Any] = {m: _PAL[i] for i, m in enumerate(FDM_MATERIALS)}
SLA_PAL: dict[str, Any] = {m: _PAL[i + 4] for i, m in enumerate(SLA_MATERIALS)}

# ─── Feature groups ───────────────────────────────────────────────────────────

LOG_X_FEATURES: set[str] = {
    "volume_cm3", "surface_area_cm2", "triangle_count",
    "bbox_x_mm", "bbox_y_mm", "bbox_z_mm", "flat_base_area_mm2",
}

DISC_GEOM: list[str] = [
    "volume_cm3", "bbox_z_mm", "min_wall_thickness_mm",
    "overhang_ratio", "complexity_index", "flat_base_area_mm2",
]

LOG_Y_BOX: set[str] = {"volume_cm3", "flat_base_area_mm2"}


# ─── Helpers ──────────────────────────────────────────────────────────────────

def proper_case(name: str) -> str:
    """Replace underscores with spaces and title-case: bbox_x_mm → Bbox X Mm."""
    return name.replace("_", " ").title()


def setup_style() -> None:
    """Apply consistent matplotlib/seaborn style for every figure."""
    sns.set_theme(style="whitegrid", palette="colorblind")
    mpl.rcParams.update({
        "font.size": 11,
        "axes.titlesize": 12,
        "axes.labelsize": 10,
        "figure.titlesize": 14,
    })


def hash_input_vector(row: pd.Series, feature_cols: list[str]) -> str:
    """Stable string key for a feature row; numerics rounded to 4 decimal places."""
    parts: list[str] = []
    for col in feature_cols:
        val = row[col]
        if isinstance(val, (float, np.floating)):
            parts.append(f"{round(float(val), 4)}")
        else:
            parts.append(str(val))
    return "|".join(parts)


# ─── Plotting functions ───────────────────────────────────────────────────────

def plot_class_distribution(df: pd.DataFrame, out_path: Path) -> dict[str, Any]:
    """3-panel bar chart: technology mix, FDM material mix, SLA material mix.

    Args:
        df: Full synthetic dataset.
        out_path: Destination PNG path.

    Returns:
        Metadata dict with tech_counts, fdm_counts, sla_counts.
    """
    setup_style()
    fig, axes = plt.subplots(1, 3, figsize=(15, 4.5), dpi=150)

    tech_counts = df["technology"].value_counts()
    fdm_counts = df[df["technology"] == "FDM"]["material"].value_counts()
    sla_counts = df[df["technology"] == "SLA"]["material"].value_counts()

    for ax, counts, title, palette in [
        (axes[0], tech_counts, "Technology Distribution", TECH_PAL),
        (axes[1], fdm_counts, "FDM Material Distribution", FDM_PAL),
        (axes[2], sla_counts, "SLA Material Distribution", SLA_PAL),
    ]:
        bars = ax.bar(counts.index, counts.values,
                      color=[palette[k] for k in counts.index])
        total = counts.sum()
        for bar, cnt in zip(bars, counts.values):
            ax.text(
                bar.get_x() + bar.get_width() / 2,
                bar.get_height() + total * 0.005,
                f"{cnt / total * 100:.1f}%",
                ha="center", va="bottom", fontsize=9,
            )
        ax.set_title(title)
        ax.set_ylabel("Number of samples")

    plt.tight_layout()
    fig.savefig(out_path, bbox_inches="tight", facecolor="white")
    plt.close(fig)

    return {
        "figure": "class_distribution",
        "path": str(out_path),
        "n_rows": len(df),
        "tech_counts": tech_counts.to_dict(),
        "fdm_counts": fdm_counts.to_dict(),
        "sla_counts": sla_counts.to_dict(),
    }


def plot_feature_distributions_by_tech(df: pd.DataFrame, out_path: Path) -> dict[str, Any]:
    """4×4 grid of geometry feature distributions split by technology.

    Args:
        df: Full synthetic dataset.
        out_path: Destination PNG path.

    Returns:
        Metadata dict with n_features.
    """
    setup_style()
    fig, axes = plt.subplots(4, 4, figsize=(16, 14), dpi=150)
    axes_flat = axes.flatten()

    for i, feat in enumerate(GEOMETRY_FEATURES):
        ax = axes_flat[i]
        if feat == "is_watertight":
            sns.countplot(data=df, x=feat, hue="technology",
                          palette=TECH_PAL, ax=ax, legend=False)
        else:
            log_x = feat in LOG_X_FEATURES
            sns.histplot(
                data=df, x=feat, hue="technology", kde=True,
                fill=True, alpha=0.4, palette=TECH_PAL, ax=ax,
                legend=False, log_scale=(log_x, False),
            )
        ax.set_title(proper_case(feat), fontsize=10)
        ax.set_xlabel("")

    legend_patches = [Patch(color=TECH_PAL[t], label=t) for t in ["FDM", "SLA"]]
    fig.legend(handles=legend_patches, loc="upper center", ncol=2,
               bbox_to_anchor=(0.5, 1.0), frameon=True)
    fig.tight_layout(rect=[0, 0, 1, 0.97])
    fig.savefig(out_path, bbox_inches="tight", facecolor="white")
    plt.close(fig)

    return {"figure": "feature_distributions_by_tech", "path": str(out_path), "n_features": 16}


def plot_separability_matrix(df: pd.DataFrame, out_path: Path) -> dict[str, Any]:
    """Pairwise material overlap heatmaps; also writes 02_separability_matrix.csv.

    Args:
        df: Full synthetic dataset.
        out_path: Destination PNG path (tables CSV is derived from this path).

    Returns:
        Metadata dict with fdm_max_overlap and sla_max_overlap.
    """
    setup_style()
    work = df.copy()
    work["_h"] = work.apply(lambda r: hash_input_vector(r, ALL_FEATURES), axis=1)

    fig, (ax_fdm, ax_sla) = plt.subplots(1, 2, figsize=(13, 5), dpi=150)
    max_overlaps: dict[str, float] = {}
    csv_rows: list[dict[str, Any]] = []

    for tech, materials, ax in [
        ("FDM", FDM_MATERIALS, ax_fdm),
        ("SLA", SLA_MATERIALS, ax_sla),
    ]:
        tech_df = work[work["technology"] == tech]
        hash_sets = {
            m: set(tech_df[tech_df["material"] == m]["_h"]) for m in materials
        }
        n = len(materials)
        mat = np.eye(n)
        for i, a in enumerate(materials):
            for j, b in enumerate(materials):
                if i != j:
                    union = hash_sets[a] | hash_sets[b]
                    inter = hash_sets[a] & hash_sets[b]
                    mat[i, j] = len(inter) / len(union) if union else 0.0

        max_overlaps[tech] = float(np.max(mat - np.eye(n)))

        overlap_df = pd.DataFrame(mat, index=materials, columns=materials)
        sns.heatmap(overlap_df, annot=True, fmt=".3f", cmap="rocket_r",
                    vmin=0, vmax=1, ax=ax, square=True)
        ax.set_title(f"{tech} Material Pairwise Overlap")

        for i in range(n):
            for j in range(i + 1, n):
                csv_rows.append({
                    "tech": tech, "material_a": materials[i],
                    "material_b": materials[j], "overlap_fraction": mat[i, j],
                })

    tables_path = out_path.parent.parent / "tables" / "02_separability_matrix.csv"
    pd.DataFrame(csv_rows).to_csv(tables_path, index=False)

    fig.suptitle("Pairwise Material Overlap (Input Feature Similarity)")
    plt.tight_layout()
    fig.savefig(out_path, bbox_inches="tight", facecolor="white")
    plt.close(fig)

    return {
        "figure": "separability_matrix",
        "path": str(out_path),
        "n_rows": len(df),
        "fdm_max_overlap": max_overlaps["FDM"],
        "sla_max_overlap": max_overlaps["SLA"],
    }


def plot_correlation_heatmap(df: pd.DataFrame, out_path: Path) -> dict[str, Any]:
    """Spearman correlation heatmap over all 16 geometry features.

    Args:
        df: Full synthetic dataset.
        out_path: Destination PNG path.

    Returns:
        Metadata dict with max_abs_offdiag.
    """
    setup_style()
    corr = df[GEOMETRY_FEATURES].apply(pd.to_numeric, errors="coerce").corr(method="spearman")
    renamed = corr.rename(index=proper_case, columns=proper_case)

    fig, ax = plt.subplots(figsize=(11, 9), dpi=150)
    sns.heatmap(renamed, annot=True, fmt=".2f", cmap="vlag", center=0,
                vmin=-1, vmax=1, square=True, ax=ax, linewidths=0.3,
                annot_kws={"size": 7})
    ax.set_title("Pairwise Spearman Correlation — Geometry Features")
    ax.set_xticklabels(ax.get_xticklabels(), rotation=45, ha="right", fontsize=8)
    ax.set_yticklabels(ax.get_yticklabels(), rotation=0, fontsize=8)

    mask = ~np.eye(len(corr), dtype=bool)
    max_abs = float(np.max(np.abs(corr.values[mask])))

    plt.tight_layout()
    fig.savefig(out_path, bbox_inches="tight", facecolor="white")
    plt.close(fig)

    return {
        "figure": "correlation_heatmap",
        "path": str(out_path),
        "n_rows": len(df),
        "max_abs_offdiag": max_abs,
    }


def plot_intent_material_crosstab(df: pd.DataFrame, out_path: Path) -> dict[str, Any]:
    """6×2 stacked-100% bar charts: material distribution by intent feature × technology.

    Args:
        df: Full synthetic dataset.
        out_path: Destination PNG path.

    Returns:
        Metadata dict.
    """
    setup_style()
    fig, axes = plt.subplots(6, 2, figsize=(14, 18), dpi=150)
    fdm_patches = [Patch(color=FDM_PAL[m], label=m) for m in FDM_MATERIALS]
    sla_patches = [Patch(color=SLA_PAL[m], label=m) for m in SLA_MATERIALS]

    for row_i, feat in enumerate(INTENT_FEATURES):
        for col_j, (tech, materials, pal) in enumerate([
            ("FDM", FDM_MATERIALS, FDM_PAL),
            ("SLA", SLA_MATERIALS, SLA_PAL),
        ]):
            ax = axes[row_i, col_j]
            sub = df[df["technology"] == tech]
            ct = pd.crosstab(sub[feat], sub["material"])
            for m in materials:
                if m not in ct.columns:
                    ct[m] = 0
            ct_pct = ct[materials].div(ct[materials].sum(axis=1), axis=0) * 100
            ct_pct.plot(kind="bar", stacked=True, ax=ax, legend=False,
                        color=[pal[m] for m in materials])
            ax.set_title(f"{tech} — by {proper_case(feat)}", fontsize=10)
            ax.set_xlabel("")
            ax.set_ylabel("%" if col_j == 0 else "")
            ax.tick_params(axis="x", rotation=30)

    axes[0, 0].legend(handles=fdm_patches, loc="upper right", fontsize=8, title="FDM")
    axes[0, 1].legend(handles=sla_patches, loc="upper right", fontsize=8, title="SLA")

    plt.tight_layout()
    fig.savefig(out_path, bbox_inches="tight", facecolor="white")
    plt.close(fig)

    return {"figure": "intent_material_crosstab", "path": str(out_path), "n_rows": len(df)}


def plot_geometry_by_material_boxplots(df: pd.DataFrame, out_path: Path) -> dict[str, Any]:
    """2×6 boxplot grid: six discriminating geometry features per technology.

    Args:
        df: Full synthetic dataset.
        out_path: Destination PNG path.

    Returns:
        Metadata dict.
    """
    setup_style()
    fig, axes = plt.subplots(2, 6, figsize=(20, 8), dpi=150)

    for row_i, (tech, materials, pal) in enumerate([
        ("FDM", FDM_MATERIALS, FDM_PAL),
        ("SLA", SLA_MATERIALS, SLA_PAL),
    ]):
        sub = df[df["technology"] == tech]
        for col_j, feat in enumerate(DISC_GEOM):
            ax = axes[row_i, col_j]
            sns.boxplot(data=sub, x="material", y=feat, order=materials,
                        hue="material", palette=pal, ax=ax, legend=False)
            ax.set_title(proper_case(feat), fontsize=10)
            ax.set_xlabel("")
            ax.set_ylabel("")
            if feat in LOG_Y_BOX:
                ax.set_yscale("log")
            ax.tick_params(axis="x", rotation=30)

    plt.tight_layout()
    fig.savefig(out_path, bbox_inches="tight", facecolor="white")
    plt.close(fig)

    return {"figure": "geometry_by_material_boxplots", "path": str(out_path), "n_rows": len(df)}


def plot_parameter_distributions_by_material(df: pd.DataFrame, out_path: Path) -> dict[str, Any]:
    """4×3 violin plot grid: parameter distributions by material (FDM top, SLA bottom).

    Args:
        df: Full synthetic dataset.
        out_path: Destination PNG path.

    Returns:
        Metadata dict.
    """
    setup_style()
    fdm = df[df["technology"] == "FDM"]
    sla = df[df["technology"] == "SLA"]

    panels: list[tuple[str, list[str], pd.DataFrame, dict[str, Any]]] = (
        [(f"param_{n}", FDM_MATERIALS, fdm, FDM_PAL) for n in FDM_PARAM_NAMES]
        + [(f"param_{n}", SLA_MATERIALS, sla, SLA_PAL) for n in SLA_PARAM_NAMES]
    )

    fig, axes = plt.subplots(4, 3, figsize=(16, 14), dpi=150)

    for idx, (col, materials, sub, pal) in enumerate(panels):
        ax = axes[idx // 3, idx % 3]
        if col in sub.columns and sub[col].notna().any():
            sns.violinplot(data=sub, x="material", y=col, order=materials,
                           hue="material", palette=pal, inner="quartile",
                           ax=ax, legend=False)
        bare = col.replace("param_", "")
        ax.set_title(proper_case(bare), fontsize=10)
        ax.set_xlabel("")
        ax.set_ylabel("")
        ax.tick_params(axis="x", rotation=30)

    plt.tight_layout()
    fig.savefig(out_path, bbox_inches="tight", facecolor="white")
    plt.close(fig)

    return {
        "figure": "parameter_distributions_by_material",
        "path": str(out_path),
        "n_rows": len(df),
    }
