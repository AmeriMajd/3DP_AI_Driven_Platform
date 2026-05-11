"""Generate Figures 1-3 from saved benchmark CSV."""
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[1]
SRC_CSV = ROOT / "reports" / "tables" / "03_benchmark_results.csv"
FAMILIES = ["random_forest", "gradient_boosting", "lightgbm", "xgboost", "catboost"]
OUT_CSV = ROOT / "results" / "benchmark_full.csv"
FIG_DIR = ROOT / "figures"
OUT_CSV.parent.mkdir(parents=True, exist_ok=True)
FIG_DIR.mkdir(parents=True, exist_ok=True)

plt.rcParams.update({
    "font.family": "DejaVu Sans",
    "figure.dpi": 100,
    "savefig.dpi": 300,
    "figure.facecolor": "white",
    "axes.facecolor": "white",
})

WINNER = "#1D9E75"
OTHER = "#B8B8B8"

LABELS = {
    "random_forest": "RandomForest",
    "gradient_boosting": "GradientBoosting",
    "lightgbm": "LightGBM",
    "xgboost": "XGBoost",
    "catboost": "CatBoost",
}

df = pd.read_csv(SRC_CSV)
df = df[df["family"].isin(FAMILIES)].copy()
out = df.rename(columns={"stage": "step", "family": "model", "metric_primary": "score"})[
    ["step", "model", "seed", "score"]
]
out.to_csv(OUT_CSV, index=False)

# Per-seed wide table
SEED_ORDER = [1337, 42, 0, 7, 2024]
per_seed = out.pivot_table(index=["step", "model"], columns="seed", values="score").reset_index()
per_seed = per_seed.rename(columns={s: f"seed_{s}" for s in SEED_ORDER})
per_seed = per_seed[["step", "model"] + [f"seed_{s}" for s in SEED_ORDER]]
per_seed_path = OUT_CSV.with_name("benchmark_per_seed.csv")
per_seed.to_csv(per_seed_path, index=False)
print("\nPer-seed table:")
print(per_seed.to_string(index=False, float_format=lambda v: f"{v:.4f}"))


def agg(stage: str) -> pd.DataFrame:
    sub = df[df["stage"] == stage]
    g = sub.groupby("family")["metric_primary"].agg(["mean", "std"]).reset_index()
    g["label"] = g["family"].map(LABELS)
    return g


def tight_ylim(groups, pad_lo: float = 0.30, pad_hi: float = 0.55) -> tuple[float, float]:
    """Zoom the y-axis to the error-bar envelope (+ headroom for value labels)."""
    if isinstance(groups, pd.DataFrame):
        groups = [groups]
    lo = min(float((g["mean"] - g["std"]).min()) for g in groups)
    hi = max(float((g["mean"] + g["std"]).max()) for g in groups)
    rng = hi - lo
    return (max(0.0, lo - pad_lo * rng), hi + pad_hi * rng)


def vbar(ax, g: pd.DataFrame, *, lower_better: bool, title: str, ylabel: str, ylim):
    g = g.sort_values("mean", ascending=lower_better).reset_index(drop=True)
    colors = [WINNER if i == 0 else OTHER for i in range(len(g))]
    x = np.arange(len(g))
    ax.bar(x, g["mean"], yerr=g["std"], color=colors,
           edgecolor="black", linewidth=0.6, width=0.62,
           error_kw={"elinewidth": 1.0, "capsize": 3, "ecolor": "#333"})
    ax.set_xticks(x)
    ax.set_xticklabels(g["label"], rotation=20, ha="right")
    ax.set_ylabel(ylabel)
    ax.set_title(title, fontsize=11)
    ax.set_ylim(*ylim)
    ax.grid(axis="y", linestyle=":", alpha=0.5)
    ax.set_axisbelow(True)
    for spine in ("top", "right"):
        ax.spines[spine].set_visible(False)
    span = ylim[1] - ylim[0]
    for i, row in g.iterrows():
        txt = f"{row['mean']:.3f} ± {row['std']:.3f}"
        ax.text(i, row["mean"] + row["std"] + span * 0.02, txt,
                ha="center", va="bottom", fontsize=8)


# --- Figure 1 : Étape 1 ---
g1 = agg("stage1_tech")
fig, ax = plt.subplots(figsize=(8, 5))
vbar(ax, g1, lower_better=False,
     title="Benchmark Étape 1 — Technologie (Macro F1, 5 graines)",
     ylabel="Macro F1", ylim=tight_ylim(g1))
fig.tight_layout()
fig.savefig(FIG_DIR / "benchmark_step1.png", dpi=300)
plt.close(fig)

# --- Figure 2 : Étape 2 (FDM | SLA) ---
g2f = agg("stage2_fdm")
g2s = agg("stage2_sla")
ylim2 = tight_ylim([g2f, g2s])
fig, axes = plt.subplots(1, 2, figsize=(14, 5))
vbar(axes[0], g2f, lower_better=False,
     title="Matériau FDM", ylabel="Macro F1", ylim=ylim2)
vbar(axes[1], g2s, lower_better=False,
     title="Matériau SLA", ylabel="Macro F1", ylim=ylim2)
fig.suptitle("Benchmark Étape 2 — Matériaux (Macro F1, 5 graines)",
             fontsize=12, y=1.02)
fig.tight_layout()
fig.savefig(FIG_DIR / "benchmark_step2.png", dpi=300, bbox_inches="tight")
plt.close(fig)

# --- Figure 3 : Étape 3 (FDM | SLA), MAE % — lower is better ---
# metric_primary for stage3 in CSV is mean MAE in % of range (one value per row).
g3f = agg("stage3_fdm")
g3s = agg("stage3_sla")
ylim3 = tight_ylim([g3f, g3s])
fig, axes = plt.subplots(1, 2, figsize=(14, 5))
vbar(axes[0], g3f, lower_better=True,
     title="Paramètres FDM", ylabel="MAE (% de plage)", ylim=ylim3)
vbar(axes[1], g3s, lower_better=True,
     title="Paramètres SLA", ylabel="MAE (% de plage)", ylim=ylim3)
fig.suptitle("Benchmark Étape 3 — Paramètres (MAE % de plage, 5 graines)",
             fontsize=12, y=1.02)
fig.tight_layout()
fig.savefig(FIG_DIR / "benchmark_step3.png", dpi=300, bbox_inches="tight")
plt.close(fig)

print("Wrote:")
print(" ", OUT_CSV)
for p in sorted(FIG_DIR.glob("benchmark_step*.png")):
    print(" ", p)
