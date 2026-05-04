"""
scripts/02_run_eda.py

Generate all EDA figures and tables for the synthetic dataset.

Usage:
    python scripts/02_run_eda.py
    python scripts/02_run_eda.py --dataset synthetic_v2
    python scripts/02_run_eda.py --prior data/synthetic_v1.parquet data/synthetic_v2.parquet

Outputs (under --reports-dir, default: reports/):
    figures/02_class_distribution.png
    figures/02_feature_distributions_by_tech.png
    figures/02_separability_matrix.png
    figures/02_correlation_heatmap.png
    figures/02_intent_material_crosstab.png
    figures/02_geometry_by_material_boxplots.png
    figures/02_parameter_distributions_by_material.png
    tables/02_class_balance.csv
    tables/02_feature_summary.csv
    tables/02_separability_matrix.csv
    tables/02_dataset_comparison.csv   (only when --prior is given)
    02_eda_summary.json
    02_figure_captions.fr.json
"""

from __future__ import annotations

import argparse
import datetime
import json
import sys
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from ml3dp.data.schema import (
    FDM_MATERIALS,
    FDM_PARAM_RANGES,
    GEOMETRY_FEATURES,
    SLA_MATERIALS,
    SLA_PARAM_RANGES,
)
from ml3dp.eda.figures import (
    ALL_FEATURES,
    hash_input_vector,
    plot_class_distribution,
    plot_correlation_heatmap,
    plot_feature_distributions_by_tech,
    plot_geometry_by_material_boxplots,
    plot_intent_material_crosstab,
    plot_parameter_distributions_by_material,
    plot_separability_matrix,
)

CAPTIONS_FR: dict[str, str] = {
    "02_class_distribution.png": (
        "Distribution des classes pour la technologie (FDM/SLA), "
        "les matériaux FDM, et les matériaux SLA."
    ),
    "02_feature_distributions_by_tech.png": (
        "Distribution de chacune des 16 caractéristiques géométriques, "
        "séparée par technologie."
    ),
    "02_separability_matrix.png": (
        "Matrice de chevauchement par paires de matériaux. "
        "Une valeur de 0 indique une séparation parfaite."
    ),
    "02_correlation_heatmap.png": (
        "Corrélation de Spearman entre les 16 caractéristiques géométriques."
    ),
    "02_intent_material_crosstab.png": (
        "Répartition des matériaux en fonction des champs d'intention "
        "utilisateur, par technologie."
    ),
    "02_geometry_by_material_boxplots.png": (
        "Distribution des principales caractéristiques géométriques par matériau."
    ),
    "02_parameter_distributions_by_material.png": (
        "Distribution des paramètres d'impression Stage 3 par matériau."
    ),
}


def _class_balance_rows(df: pd.DataFrame) -> list[dict]:
    rows = []
    for tech in ["FDM", "SLA"]:
        cnt = int((df["technology"] == tech).sum())
        rows.append({"level": "technology", "label": tech,
                     "count": cnt, "fraction": cnt / len(df)})
    fdm = df[df["technology"] == "FDM"]
    for mat in FDM_MATERIALS:
        cnt = int((fdm["material"] == mat).sum())
        rows.append({"level": "material_fdm", "label": mat,
                     "count": cnt, "fraction": cnt / len(fdm) if len(fdm) else 0.0})
    sla = df[df["technology"] == "SLA"]
    for mat in SLA_MATERIALS:
        cnt = int((sla["material"] == mat).sum())
        rows.append({"level": "material_sla", "label": mat,
                     "count": cnt, "fraction": cnt / len(sla) if len(sla) else 0.0})
    return rows


def _feature_summary_rows(df: pd.DataFrame) -> list[dict]:
    rows = []
    for feat in GEOMETRY_FEATURES:
        s = pd.to_numeric(df[feat], errors="coerce")
        rows.append({
            "feature": feat,
            "dtype": str(df[feat].dtype),
            "n_unique": int(df[feat].nunique()),
            "n_missing": int(df[feat].isna().sum()),
            "min": float(s.min()),
            "q25": float(s.quantile(0.25)),
            "median": float(s.median()),
            "q75": float(s.quantile(0.75)),
            "max": float(s.max()),
            "mean": float(s.mean()),
            "std": float(s.std()),
        })
    return rows


def _dataset_metrics(df: pd.DataFrame) -> dict:
    metrics: dict = {
        "n_rows": len(df),
        "n_columns": len(df.columns),
        "tech_fdm_pct": None,
        "tech_sla_pct": None,
        "fdm_imbalance_ratio": None,
        "sla_imbalance_ratio": None,
        "max_pairwise_overlap": None,
    }
    if "technology" in df.columns:
        tc = df["technology"].value_counts()
        n = len(df)
        metrics["tech_fdm_pct"] = float(tc.get("FDM", 0) / n)
        metrics["tech_sla_pct"] = float(tc.get("SLA", 0) / n)

    if "material" in df.columns and "technology" in df.columns:
        fdm_mc = df[df["technology"] == "FDM"]["material"].value_counts()
        sla_mc = df[df["technology"] == "SLA"]["material"].value_counts()
        if len(fdm_mc) >= 2:
            metrics["fdm_imbalance_ratio"] = float(fdm_mc.max() / fdm_mc.min())
        if len(sla_mc) >= 2:
            metrics["sla_imbalance_ratio"] = float(sla_mc.max() / sla_mc.min())

    if all(f in df.columns for f in ALL_FEATURES) and "material" in df.columns:
        try:
            work = df.copy()
            work["_h"] = work.apply(
                lambda r: hash_input_vector(r, ALL_FEATURES), axis=1
            )
            max_ov = 0.0
            for tech, materials in [("FDM", FDM_MATERIALS), ("SLA", SLA_MATERIALS)]:
                tech_df = work[work["technology"] == tech] if "technology" in work.columns else work
                hash_sets = {
                    m: set(tech_df[tech_df["material"] == m]["_h"]) for m in materials
                    if m in tech_df["material"].values
                }
                mats = list(hash_sets.keys())
                for i, a in enumerate(mats):
                    for b in mats[i + 1:]:
                        union = hash_sets[a] | hash_sets[b]
                        inter = hash_sets[a] & hash_sets[b]
                        ov = len(inter) / len(union) if union else 0.0
                        max_ov = max(max_ov, ov)
            metrics["max_pairwise_overlap"] = max_ov
        except Exception:
            pass

    return metrics


def _run_comparison(prior_paths: list[str], current_df: pd.DataFrame,
                    current_name: str) -> list[dict]:
    rows = []
    for path in prior_paths:
        try:
            prior_df = pd.read_parquet(path)
            m = _dataset_metrics(prior_df)
            m["dataset"] = Path(path).stem
            rows.append(m)
        except Exception as exc:
            print(f"Warning: could not load prior {path}: {exc}")
    current = _dataset_metrics(current_df)
    current["dataset"] = current_name
    rows.append(current)
    return rows


def main() -> None:
    parser = argparse.ArgumentParser(description="Run EDA on synthetic dataset.")
    parser.add_argument("--dataset", default="synthetic_v3")
    parser.add_argument("--data-dir", default=str(ROOT / "data"))
    parser.add_argument("--reports-dir", default=str(ROOT / "reports"))
    parser.add_argument("--prior", nargs="*", default=[], metavar="PATH")
    args = parser.parse_args()

    data_dir = Path(args.data_dir)
    reports_dir = Path(args.reports_dir)
    parquet_path = data_dir / f"{args.dataset}.parquet"

    if not parquet_path.exists():
        print(f"Error: dataset not found at {parquet_path}")
        print(f"  Run scripts/01_generate_dataset.py first.")
        sys.exit(1)

    print(f"Loading {parquet_path} …")
    df = pd.read_parquet(parquet_path)
    print(f"  {len(df):,} rows × {len(df.columns)} columns")

    figs_dir = reports_dir / "figures"
    tables_dir = reports_dir / "tables"
    figs_dir.mkdir(parents=True, exist_ok=True)
    tables_dir.mkdir(parents=True, exist_ok=True)

    figure_specs = [
        ("02_class_distribution.png",                  plot_class_distribution),
        ("02_feature_distributions_by_tech.png",       plot_feature_distributions_by_tech),
        ("02_separability_matrix.png",                 plot_separability_matrix),
        ("02_correlation_heatmap.png",                 plot_correlation_heatmap),
        ("02_intent_material_crosstab.png",            plot_intent_material_crosstab),
        ("02_geometry_by_material_boxplots.png",       plot_geometry_by_material_boxplots),
        ("02_parameter_distributions_by_material.png", plot_parameter_distributions_by_material),
    ]

    figure_metas: list[dict] = []
    for fname, fn in figure_specs:
        out = figs_dir / fname
        print(f"  Plotting {fname} …")
        meta = fn(df, out)
        figure_metas.append(meta)

    balance_path = tables_dir / "02_class_balance.csv"
    pd.DataFrame(_class_balance_rows(df)).to_csv(balance_path, index=False)

    summary_path = tables_dir / "02_feature_summary.csv"
    pd.DataFrame(_feature_summary_rows(df)).to_csv(summary_path, index=False)

    table_paths = [balance_path, summary_path,
                   tables_dir / "02_separability_matrix.csv"]

    if args.prior:
        comp_rows = _run_comparison(args.prior, df, args.dataset)
        comp_path = tables_dir / "02_dataset_comparison.csv"
        pd.DataFrame(comp_rows).to_csv(comp_path, index=False)
        table_paths.append(comp_path)
        print(f"  Comparison table written ({len(comp_rows)} datasets).")

    captions_path = reports_dir / "02_figure_captions.fr.json"
    with open(captions_path, "w", encoding="utf-8") as f:
        json.dump(CAPTIONS_FR, f, ensure_ascii=False, indent=2)

    tech_counts = df["technology"].value_counts()
    fdm_mats = df[df["technology"] == "FDM"]["material"].value_counts()
    sla_mats = df[df["technology"] == "SLA"]["material"].value_counts()
    n = len(df)

    sep_meta = next(m for m in figure_metas if m["figure"] == "separability_matrix")

    headline = {
        "tech_fdm_pct": round(tech_counts.get("FDM", 0) / n, 4),
        "tech_sla_pct": round(tech_counts.get("SLA", 0) / n, 4),
        "fdm_imbalance_ratio": round(fdm_mats.max() / fdm_mats.min(), 4) if len(fdm_mats) >= 2 else None,
        "sla_imbalance_ratio": round(sla_mats.max() / sla_mats.min(), 4) if len(sla_mats) >= 2 else None,
        "max_fdm_pairwise_overlap": sep_meta["fdm_max_overlap"],
        "max_sla_pairwise_overlap": sep_meta["sla_max_overlap"],
    }

    eda_summary = {
        "dataset": args.dataset,
        "n_rows": len(df),
        "n_columns": len(df.columns),
        "generated_at": datetime.datetime.now().isoformat(),
        "figures": figure_metas,
        "tables": [str(p) for p in table_paths],
        "headline_metrics": headline,
    }

    eda_path = reports_dir / "02_eda_summary.json"
    with open(eda_path, "w", encoding="utf-8") as f:
        json.dump(eda_summary, f, indent=2)

    written = (
        [str(figs_dir / s) for s, _ in figure_specs]
        + [str(p) for p in table_paths]
        + [str(eda_path), str(captions_path)]
    )

    print("\n-- Files written ------------------------------------------")
    for p in written:
        print(f"  {p}")
    print("\n-- Headline metrics ---------------------------------------")
    for k, v in headline.items():
        print(f"  {k}: {v}")
    print()


if __name__ == "__main__":
    main()
