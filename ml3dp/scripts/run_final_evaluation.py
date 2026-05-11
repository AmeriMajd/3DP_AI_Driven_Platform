"""Final canonical evaluation + deployment artifacts for the thesis chapter.

ONE fixed seed (1337). For each of the 5 tuned (stage, model) pairs:
  - train on TRAIN + VALIDATION combined,
  - evaluate ONCE on the held-out TEST set,
  - serialize the fitted model for the FastAPI inference pipeline.

Plus: confusion matrices (stage 2 FDM/SLA), permutation-importance plots
(stage 1 + stage 2 FDM), and the supporting label / feature-name artifacts.

No re-tuning — hyperparameters are read verbatim from results/optuna_best_params.json.
If anything is wrong (bad hyperparameter, fit failure, missing feature) the script
stops and reports rather than working around it.

Outputs
  results/final_test_scores.csv
  figures/confusion_matrix_stage2_fdm.png
  figures/confusion_matrix_stage2_sla.png
  figures/feature_importance_stage1.png
  figures/feature_importance_stage2_fdm.png
  backend/models_ml/stage1_classifier.joblib
  backend/models_ml/stage2a_material.joblib
  backend/models_ml/stage2b_material.joblib
  backend/models_ml/stage3a_regressor.joblib
  backend/models_ml/stage3b_regressor.joblib
  backend/models_ml/label_encoders.joblib   (intent ordinal maps + label spaces)
  backend/models_ml/feature_names.joblib     (per-stage feature column order)
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ML_ROOT = Path(__file__).resolve().parents[1]      # .../ml3dp
REPO_ROOT = ML_ROOT.parent                          # repo root
sys.path.insert(0, str(ML_ROOT / "src"))

import joblib
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from sklearn.ensemble import RandomForestRegressor
from sklearn.inspection import permutation_importance
from sklearn.metrics import confusion_matrix, f1_score, mean_absolute_error
from sklearn.multioutput import MultiOutputRegressor

try:
    from lightgbm import LGBMClassifier
except ImportError:  # pragma: no cover
    LGBMClassifier = None  # type: ignore
try:
    from catboost import CatBoostClassifier
except ImportError:  # pragma: no cover
    CatBoostClassifier = None  # type: ignore

from ml3dp.data.schema import (
    FDM_MATERIALS,
    FDM_PARAM_NAMES,
    FDM_PARAM_RANGES,
    INTENT_VALUES,
    SLA_MATERIALS,
    SLA_PARAM_NAMES,
    SLA_PARAM_RANGES,
    TECHNOLOGIES,
)
from ml3dp.features.encoder import INTENT_CATEGORICAL
from ml3dp.features.prepare import prepare_all_stages

SEED = 1337

RESULTS = ML_ROOT / "results"
FIG_DIR = ML_ROOT / "figures"
MODELS_DIR = REPO_ROOT / "backend" / "models_ml"
DATA_PARQUET = ML_ROOT / "data" / "synthetic_v3.parquet"
BEST_PARAMS_JSON = RESULTS / "optuna_best_params.json"

WINNERS: dict[str, str] = {
    "stage1_tech": "catboost",
    "stage2_fdm": "lightgbm",
    "stage2_sla": "catboost",
    "stage3_fdm": "random_forest",
    "stage3_sla": "random_forest",
}
CLASSIFICATION_STAGES = {"stage1_tech", "stage2_fdm", "stage2_sla"}
THRESHOLDS: dict[str, float] = {
    "stage1_tech": 0.90,
    "stage2_fdm": 0.85,
    "stage2_sla": 0.85,
    "stage3_fdm": 10.0,
    "stage3_sla": 10.0,
}
DEPLOY_NAMES: dict[str, str] = {
    "stage1_tech": "stage1_classifier.joblib",
    "stage2_fdm": "stage2a_material.joblib",
    "stage2_sla": "stage2b_material.joblib",
    "stage3_fdm": "stage3a_regressor.joblib",
    "stage3_sla": "stage3b_regressor.joblib",
}
PARAM_RANGES = {"stage3_fdm": FDM_PARAM_RANGES, "stage3_sla": SLA_PARAM_RANGES}
MAT_CLASSES = {"stage2_fdm": FDM_MATERIALS, "stage2_sla": SLA_MATERIALS}

plt.rcParams.update({
    "font.family": "DejaVu Sans",
    "figure.dpi": 100,
    "savefig.dpi": 300,
    "figure.facecolor": "white",
    "axes.facecolor": "white",
})
BAR = "#1D9E75"


def fail(msg: str) -> "NoReturn":  # type: ignore[name-defined]
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def coerce(value):
    """JSON brings integer hyperparameters back as strings ("10", "100"); cast them."""
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


def build_model(family: str, params: dict):
    """Instantiate the winning family with tuned params + the corrected-benchmark balancing."""
    if family == "catboost":
        if CatBoostClassifier is None:
            fail("catboost is not installed")
        return CatBoostClassifier(**params, verbose=0, auto_class_weights="Balanced",
                                  random_state=SEED)
    if family == "lightgbm":
        if LGBMClassifier is None:
            fail("lightgbm is not installed")
        return LGBMClassifier(**params, class_weight="balanced", verbose=-1, random_state=SEED)
    if family == "random_forest":
        # stage 3 — multi-output regression, no class balancing
        return MultiOutputRegressor(RandomForestRegressor(**params, random_state=SEED))
    fail(f"unhandled family: {family}")


def _predict_labels(model, X) -> np.ndarray:
    return np.asarray(model.predict(X)).ravel()


# ─────────────────────────────────────────────────────────────────────────────
def main() -> None:
    if not DATA_PARQUET.exists():
        fail(f"dataset not found: {DATA_PARQUET}")
    if not BEST_PARAMS_JSON.exists():
        fail(f"tuned params not found: {BEST_PARAMS_JSON}")

    df = pd.read_parquet(DATA_PARQUET)
    raw_params: dict[str, dict] = json.loads(BEST_PARAMS_JSON.read_text())
    for stage in WINNERS:
        if stage not in raw_params:
            fail(f"{stage} missing from {BEST_PARAMS_JSON.name}")

    try:
        splits = prepare_all_stages(df, encoder_kind="ordinal", seed=SEED)
    except AssertionError as exc:
        fail(f"feature/schema check failed while preparing splits: {exc}")

    FIG_DIR.mkdir(parents=True, exist_ok=True)
    RESULTS.mkdir(parents=True, exist_ok=True)
    MODELS_DIR.mkdir(parents=True, exist_ok=True)

    # ── TASK 1 — train on train+val, evaluate on test ───────────────────────
    fitted: dict[str, object] = {}
    score_rows: list[dict] = []
    summary: list[tuple] = []

    for stage, family in WINNERS.items():
        params = {k: coerce(v) for k, v in raw_params[stage].items()}
        try:
            model = build_model(family, params)
        except TypeError as exc:
            fail(f"{stage}/{family}: unsupported hyperparameter ({exc}); params={params}")

        sp = splits[stage]
        X_tv = pd.concat([sp.X_train, sp.X_val])
        y_tv = pd.concat([sp.y_train, sp.y_val])
        try:
            model.fit(X_tv, y_tv)
        except Exception as exc:  # bad param that only bites at fit time, etc.
            fail(f"{stage}/{family} failed to fit (params={params}): {exc}")
        fitted[stage] = model

        if stage in CLASSIFICATION_STAGES:
            y_pred = _predict_labels(model, sp.X_test)
            f1 = float(f1_score(sp.y_test, y_pred, average="macro"))
            score_rows.append({"stage": stage, "model": family, "metric": "macro_f1", "score": f1})
            ok = f1 >= THRESHOLDS[stage]
            summary.append((stage, family, "Macro F1", f1, THRESHOLDS[stage], ">=", ok))
        else:
            y_pred = pd.DataFrame(model.predict(sp.X_test), columns=sp.y_test.columns,
                                  index=sp.y_test.index)
            ranges = PARAM_RANGES[stage]
            per_param_pct: dict[str, float] = {}
            for col in sp.y_test.columns:
                key = col.removeprefix("param_")
                lo, hi = ranges[key]
                mae = mean_absolute_error(sp.y_test[col], y_pred[col])
                per_param_pct[key] = float(mae / (hi - lo) * 100)
            mean_pct = float(np.mean(list(per_param_pct.values())))
            score_rows.append({"stage": stage, "model": family,
                               "metric": "mae_pct_of_range", "score": mean_pct})
            for key, v in per_param_pct.items():
                # per-parameter MAE expressed as % of that parameter's range (comparable across params)
                score_rows.append({"stage": stage, "model": family,
                                   "metric": f"MAE_param_{key}", "score": v})
            ok = mean_pct <= THRESHOLDS[stage]
            summary.append((stage, family, "MAE % range", mean_pct, THRESHOLDS[stage], "<=", ok))

    pd.DataFrame(score_rows)[["stage", "model", "metric", "score"]].to_csv(
        RESULTS / "final_test_scores.csv", index=False
    )

    # ── TASK 2 — normalized confusion matrices (stage 2 FDM/SLA) ────────────
    cm_meta = {
        "stage2_fdm": ("FDM", "LightGBM"),
        "stage2_sla": ("SLA", "CatBoost"),
    }
    for stage, (branch, model_name) in cm_meta.items():
        classes = list(MAT_CLASSES[stage])
        sp = splits[stage]
        y_pred = _predict_labels(fitted[stage], sp.X_test)
        cm = confusion_matrix(sp.y_test, y_pred, labels=classes, normalize="true")
        n = len(classes)
        fig, ax = plt.subplots(figsize=(5.4, 4.8) if n > 2 else (4.4, 3.9))
        im = ax.imshow(cm, cmap="Blues", vmin=0.0, vmax=1.0)
        ax.set_xticks(range(n)); ax.set_xticklabels(classes, rotation=20, ha="right")
        ax.set_yticks(range(n)); ax.set_yticklabels(classes)
        for i in range(n):
            for j in range(n):
                v = cm[i, j]
                ax.text(j, i, f"{v:.2f}", ha="center", va="center",
                        color="white" if v > 0.5 else "#222", fontsize=11)
        ax.set_xlabel("Prédit")
        ax.set_ylabel("Réel")
        ax.set_title(f"Matrice de confusion normalisée — Étape 2 {branch} ({model_name})",
                     fontsize=11)
        fig.colorbar(im, ax=ax, fraction=0.046, pad=0.04)
        fig.tight_layout()
        fig.savefig(FIG_DIR / f"confusion_matrix_{stage}.png", dpi=300, bbox_inches="tight")
        plt.close(fig)

    # ── TASK 3 — permutation feature importance (stage 1 + stage 2 FDM) ─────
    pi_meta = {
        "stage1_tech": ("Étape 1", 0.40, "feature_importance_stage1.png"),
        "stage2_fdm": ("Étape 2 (FDM)", 0.25, "feature_importance_stage2_fdm.png"),
    }
    for stage, (label, xmax_floor, fname) in pi_meta.items():
        sp = splits[stage]
        r = permutation_importance(
            fitted[stage], sp.X_test, sp.y_test,
            n_repeats=10, random_state=SEED, scoring="f1_macro",
        )
        feats = list(sp.X_test.columns)
        idx = np.argsort(r.importances_mean)[::-1]          # descending
        names = [feats[i] for i in idx]
        means = r.importances_mean[idx]
        stds = r.importances_std[idx]
        fig, ax = plt.subplots(figsize=(8.5, max(4.5, 0.34 * len(feats))))
        y = np.arange(len(names))
        ax.barh(y, means, xerr=stds, color=BAR, edgecolor="black", linewidth=0.5,
                error_kw={"elinewidth": 0.9, "ecolor": "#333", "capsize": 2})
        ax.set_yticks(y); ax.set_yticklabels(names)
        ax.invert_yaxis()                                   # largest on top
        ax.set_xlabel("Diminution de performance (permutation)")
        ax.set_title(f"Importances des features par permutation — {label}", fontsize=11)
        ax.set_xlim(0.0, max(xmax_floor, float((means + stds).max()) * 1.05))
        ax.grid(axis="x", linestyle=":", alpha=0.5)
        ax.set_axisbelow(True)
        for spine in ("top", "right"):
            ax.spines[spine].set_visible(False)
        fig.tight_layout()
        fig.savefig(FIG_DIR / fname, dpi=300, bbox_inches="tight")
        plt.close(fig)

    # ── TASK 4 — serialize deployment artifacts ─────────────────────────────
    for stage, fname in DEPLOY_NAMES.items():
        joblib.dump(fitted[stage], MODELS_DIR / fname)

    feature_names = {stage: list(splits[stage].feature_names) for stage in WINNERS}
    joblib.dump(feature_names, MODELS_DIR / "feature_names.joblib")

    # Intent ordinal maps are deterministic from the schema (the encoder ignores the
    # data on fit); store them as plain dicts so the backend needs no ml3dp import.
    label_encoders = {
        "intent_ordinal": {
            col: {value: i for i, value in enumerate(INTENT_VALUES[col])}
            for col in INTENT_CATEGORICAL
        },
        "technologies": list(TECHNOLOGIES),
        "fdm_materials": list(FDM_MATERIALS),
        "sla_materials": list(SLA_MATERIALS),
    }
    joblib.dump(label_encoders, MODELS_DIR / "label_encoders.joblib")

    # ── console summary ─────────────────────────────────────────────────────
    print(f"\n=== Final test-set evaluation  (seed={SEED}; trained on train+val) ===")
    print(f"  {'stage':<14} {'model':<14} {'metric':<13} {'score':>12} {'threshold':>14} {'status':>8}")
    for stage, family, metric, score, thr, op, ok in summary:
        is_clf = metric.startswith("Macro")
        sc = f"{score:.4f}" if is_clf else f"{score:.3f} %"
        th = f"{op} {thr:.2f}" + ("" if is_clf else " %")
        print(f"  {stage:<14} {family:<14} {metric:<13} {sc:>12} {th:>14} {'PASS' if ok else 'FAIL':>8}")
    n_pass = sum(1 for *_, ok in summary if ok)
    print(f"\n  {n_pass}/{len(summary)} stages PASS acceptance thresholds.")

    print("\nPer-parameter MAE (% of range) on test set:")
    for stage in ("stage3_fdm", "stage3_sla"):
        rows = [r for r in score_rows if r["stage"] == stage and r["metric"].startswith("MAE_param_")]
        rows.sort(key=lambda r: r["score"])
        pretty = "  ".join(f"{r['metric'].removeprefix('MAE_param_')}={r['score']:.2f}%" for r in rows)
        print(f"  {stage}: {pretty}")

    print("\nWrote:")
    print(f"  {(RESULTS / 'final_test_scores.csv')}")
    for p in ("confusion_matrix_stage2_fdm.png", "confusion_matrix_stage2_sla.png",
              "feature_importance_stage1.png", "feature_importance_stage2_fdm.png"):
        print(f"  {FIG_DIR / p}")
    for fname in list(DEPLOY_NAMES.values()) + ["label_encoders.joblib", "feature_names.joblib"]:
        print(f"  {MODELS_DIR / fname}")


if __name__ == "__main__":
    main()
