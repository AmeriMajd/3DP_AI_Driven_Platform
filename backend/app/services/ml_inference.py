"""
ML inference pipeline for 3D print recommendations.

Pipeline:
  Stage 1 (stage1_classifier)  — FDM vs SLA
  Stage 2a (stage2a_material)  — material class (6 labels)
  Stage 2b (stage2b_regressor) — 6 slicer parameters

Drop the .joblib files produced by train_models.py into backend/models_ml/:
    stage1_classifier.joblib
    stage2a_material.joblib
    stage2b_regressor.joblib
    label_encoders.joblib
    feature_names.joblib
"""

from __future__ import annotations

import logging
from pathlib import Path
from typing import Any

import numpy as np

logger = logging.getLogger(__name__)

# Path where the trained .joblib files live
MODELS_DIR = Path(__file__).parent.parent.parent / "models_ml"

# ── Confidence tier thresholds ─────────────────────────────────────────────────
_TECH_HIGH = 0.85
_TECH_MED = 0.60
_MAT_HIGH = 0.70
_MAT_MED = 0.45

# Output parameter names — must match MultiOutputRegressor target order from training
_PARAM_NAMES = [
    "layer_height",
    "infill_density",
    "print_speed",
    "wall_count",
    "cooling_fan",
    "support_density",
]

# Clarification questions keyed by (material_a, material_b) confusion
_CLARIFICATIONS: dict[tuple[str, str], tuple[str, str]] = {
    ("FDM", "SLA"): (
        "Is fine surface detail more important than keeping costs low?",
        "surface_finish",
    ),
    ("PLA", "PETG"): (
        "Will this part bear mechanical load or just be decorative?",
        "strength_required",
    ),
    ("ABS", "PETG"): (
        "Will this part be exposed to temperatures above 60°C?",
        "outdoor_use",
    ),
    ("PETG", "TPU"): (
        "Does this part need to flex or bend during use?",
        "needs_flexibility",
    ),
    ("Resin-Standard", "Resin-Engineering"): (
        "Does this part need to withstand mechanical stress?",
        "strength_required",
    ),
}


# ── Singleton model holder ─────────────────────────────────────────────────────

class _MLModels:
    """Lazy-loaded singleton that holds all four joblib artifacts."""

    _instance: "_MLModels | None" = None

    def __init__(self) -> None:
        self.stage1 = None
        self.stage2a = None
        self.stage2b = None
        self.label_encoders: dict = {}
        self.feature_names: list[str] = []
        self._loaded = False

    @classmethod
    def get(cls) -> "_MLModels":
        if cls._instance is None:
            cls._instance = _MLModels()
        return cls._instance

    def load(self) -> None:
        if self._loaded:
            return
        try:
            import joblib  # imported here so the module is importable without sklearn installed

            self.stage1 = joblib.load(MODELS_DIR / "stage1_classifier.joblib")
            self.stage2a = joblib.load(MODELS_DIR / "stage2a_material.joblib")
            self.stage2b = joblib.load(MODELS_DIR / "stage2b_regressor.joblib")
            self.label_encoders = joblib.load(MODELS_DIR / "label_encoders.joblib")
            self.feature_names = list(joblib.load(MODELS_DIR / "feature_names.joblib"))
            self._loaded = True
            logger.info("ML models loaded successfully from %s", MODELS_DIR)
        except Exception as exc:
            logger.error("Failed to load ML models from %s: %s", MODELS_DIR, exc)
            raise

    @property
    def available(self) -> bool:
        return self._loaded


def models_available() -> bool:
    """Return True if the .joblib files exist and have been loaded."""
    m = _MLModels.get()
    if m.available:
        return True
    try:
        m.load()
        return True
    except Exception:
        return False


# ── Feature vector construction ────────────────────────────────────────────────

def _encode(encoders: dict, col: str, val: str) -> int:
    enc = encoders.get(col)
    if enc is None:
        return 0
    try:
        return int(enc.transform([val])[0])
    except Exception:
        logger.warning("Unseen label '%s' for encoder '%s', defaulting to 0", val, col)
        return 0


def _build_base_features(geo: dict, intent: dict, models: _MLModels) -> np.ndarray:
    """
    Assemble the 22 base features (16 geometry + 6 user intent) in the
    exact column order used during training (given by feature_names.joblib).
    """
    enc = models.label_encoders

    row: dict[str, Any] = {
        # ── Geometry (16) ──────────────────────────────────────────────────────
        "volume_cm3":            float(geo.get("volume_cm3") or 0.0),
        "surface_area_cm2":      float(geo.get("surface_area_cm2") or 0.0),
        "bbox_x_mm":             float(geo.get("bbox_x_mm") or 0.0),
        "bbox_y_mm":             float(geo.get("bbox_y_mm") or 0.0),
        "bbox_z_mm":             float(geo.get("bbox_z_mm") or 0.0),
        "triangle_count":        int(geo.get("triangle_count") or 0),
        "overhang_ratio":        float(geo.get("overhang_ratio") or 0.0),
        "max_overhang_angle":    float(geo.get("max_overhang_angle") or 0.0),
        "min_wall_thickness_mm": float(geo.get("min_wall_thickness_mm") or 1.0),
        "avg_wall_thickness_mm": float(geo.get("avg_wall_thickness_mm") or 2.0),
        "complexity_index":      float(geo.get("complexity_index") or 1.0),
        "aspect_ratio":          float(geo.get("aspect_ratio") or 1.0),
        "is_watertight":         int(bool(geo.get("is_watertight", True))),
        "shell_count":           int(geo.get("shell_count") or 1),
        "com_offset_ratio":      float(geo.get("com_offset_ratio") or 0.0),
        "flat_base_area_mm2":    float(geo.get("flat_base_area_mm2") or 0.0),
        # ── User intent (6) ────────────────────────────────────────────────────
        "intended_use":      _encode(enc, "intended_use",      intent["intended_use"]),
        "surface_finish":    _encode(enc, "surface_finish",    intent["surface_finish"]),
        "needs_flexibility": int(bool(intent["needs_flexibility"])),
        "strength_required": _encode(enc, "strength_required", intent["strength_required"]),
        "budget_priority":   _encode(enc, "budget_priority",   intent["budget_priority"]),
        "outdoor_use":       int(bool(intent["outdoor_use"])),
    }

    return np.array([[row[f] for f in models.feature_names]], dtype=float)


def _encode_label(encoders: dict, col: str, val: str, fallback: int) -> int:
    """Encode a target label for use as a downstream feature."""
    enc = encoders.get(col)
    if enc is None:
        return fallback
    try:
        return int(enc.transform([val])[0])
    except Exception:
        return fallback


# ── Post-processing ────────────────────────────────────────────────────────────

def _clamp_params(raw: dict[str, float], technology: str) -> dict[str, Any]:
    """Apply valid-range clamping, rounding, and SLA override rules."""

    def clamp(v: float, lo: float, hi: float) -> float:
        return max(lo, min(hi, v))

    def snap(v: float, step: float) -> float:
        return round(round(v / step) * step, 10)

    out: dict[str, Any] = {
        "layer_height":   snap(clamp(raw["layer_height"],   0.05, 0.35), 0.05),
        "infill_density": int(snap(clamp(raw["infill_density"], 10,  100), 5)),
        "print_speed":    int(snap(clamp(raw["print_speed"],    30,  120), 5)),
        "wall_count":     int(clamp(round(raw["wall_count"]),   1,   5)),
        "cooling_fan":    int(snap(clamp(raw["cooling_fan"],    0,   100), 5)),
        "support_density":int(snap(clamp(raw["support_density"],0,   30),  5)),
    }

    if technology == "SLA":
        out["infill_density"] = 100
        out["cooling_fan"] = 0
        out["wall_count"] = 0

    return out


# ── Parameter uncertainty ranges ──────────────────────────────────────────────

def _param_ranges(stage2b, X: np.ndarray, params: dict[str, Any]) -> dict[str, Any]:
    """
    Compute per-tree standard deviation for each regression target.
    Returns layer_height_min / layer_height_max when uncertainty is non-trivial.
    """
    result: dict[str, Any] = {"layer_height_min": None, "layer_height_max": None}
    try:
        for i, (estimator, name) in enumerate(zip(stage2b.estimators_, _PARAM_NAMES)):
            tree_preds = np.array([t.predict(X)[0] for t in estimator.estimators_])
            std = float(np.std(tree_preds))
            pred = params[name]

            relative = std / abs(pred) if pred != 0 else 0.0
            if name == "layer_height" and relative > 0.10:
                result["layer_height_min"] = round(max(0.05, pred - std), 3)
                result["layer_height_max"] = round(min(0.35, pred + std), 3)
    except Exception as exc:
        logger.warning("Could not compute parameter uncertainty ranges: %s", exc)
    return result


# ── Score derivation ───────────────────────────────────────────────────────────

def _compute_scores(technology: str, material: str, params: dict[str, Any]) -> dict[str, int]:
    """Derive cost / quality / speed scores (0–100) from the predicted parameters."""

    # ── Cost ──────────────────────────────────────────────────────────────────
    cost = 35 if technology == "SLA" else 75
    cost += {"PLA": 10, "PETG": 0, "ABS": -5, "TPU": -10,
             "Resin-Standard": 0, "Resin-Engineering": -10}.get(material, 0)
    cost += int((100 - params["infill_density"]) * 0.10)
    cost = max(10, min(100, cost))

    # ── Quality ───────────────────────────────────────────────────────────────
    lh = params["layer_height"]
    if technology == "SLA":
        quality = int(90 + (0.10 - lh) / 0.05 * 5)
    else:
        quality = int(95 - (lh - 0.05) / 0.30 * 40)
    quality += (params["wall_count"] - 2) * 3
    quality = max(20, min(100, quality))

    # ── Speed ─────────────────────────────────────────────────────────────────
    speed = int(40 + (params["print_speed"] - 30) / 90 * 40)
    if technology == "SLA":
        speed = max(20, speed - 20)
    if material == "TPU":
        speed -= 15
    speed += int((100 - params["infill_density"]) * 0.10)
    speed = max(10, min(100, speed))

    return {"cost_score": cost, "quality_score": quality, "speed_score": speed}


# ── Confidence tiers ───────────────────────────────────────────────────────────

def _tech_tier(conf: float) -> str:
    return "high" if conf >= _TECH_HIGH else ("medium" if conf >= _TECH_MED else "low")


def _mat_tier(conf: float) -> str:
    return "high" if conf >= _MAT_HIGH else ("medium" if conf >= _MAT_MED else "low")


def _overall_tier(tech_tier: str, mat_tier: str) -> str:
    rank = {"high": 2, "medium": 1, "low": 0}
    return tech_tier if rank[tech_tier] <= rank[mat_tier] else mat_tier


# ── Clarification helpers ──────────────────────────────────────────────────────

def _clarification_for_tech_confusion() -> tuple[str, str]:
    return _CLARIFICATIONS[("FDM", "SLA")]


def _clarification_for_material(material: str) -> tuple[str, str] | tuple[None, None]:
    for (m1, m2), (q, f) in _CLARIFICATIONS.items():
        if material in (m1, m2):
            return q, f
    return None, None


# ── Public inference function ──────────────────────────────────────────────────

def predict(geo: dict, intent: dict) -> dict[str, Any]:
    """
    Run the full three-stage ML pipeline and return a result dict whose keys
    map 1-to-1 with the fields written by recommendation_service.create_recommendation().

    Parameters
    ----------
    geo : dict
        Geometry features. Keys match STLFile ORM column names
        (volume_cm3, overhang_ratio, …).  NULL/None values are replaced by
        safe defaults so a partially-analysed file still yields a prediction.

    intent : dict
        User intent with keys:
            intended_use, surface_finish, needs_flexibility,
            strength_required, budget_priority, outdoor_use
    """
    models = _MLModels.get()
    models.load()

    X = _build_base_features(geo, intent, models)

    # ── Stage 1: Technology ───────────────────────────────────────────────────
    tech_proba: np.ndarray = models.stage1.predict_proba(X)[0]
    tech_classes: list[str] = list(models.stage1.classes_)
    tech_idx = int(np.argmax(tech_proba))
    technology = tech_classes[tech_idx]
    tech_conf = float(tech_proba[tech_idx])
    t_tier = _tech_tier(tech_conf)

    # Encode technology for use as a Stage 2a feature
    tech_encoded = _encode_label(models.label_encoders, "technology", technology, tech_idx)
    X2a = np.hstack([X, [[tech_encoded]]])

    # ── Stage 2a: Material ────────────────────────────────────────────────────
    mat_proba: np.ndarray = models.stage2a.predict_proba(X2a)[0]
    mat_classes: list[str] = list(models.stage2a.classes_)
    mat_idx = int(np.argmax(mat_proba))
    material = mat_classes[mat_idx]
    mat_conf = float(mat_proba[mat_idx])
    m_tier = _mat_tier(mat_conf)

    # Encode material for use as a Stage 2b feature
    mat_encoded = _encode_label(models.label_encoders, "material", material, mat_idx)
    X2b = np.hstack([X2a, [[mat_encoded]]])

    # ── Stage 2b: Parameters ──────────────────────────────────────────────────
    raw_pred: np.ndarray = models.stage2b.predict(X2b)[0]
    raw_params = dict(zip(_PARAM_NAMES, [float(v) for v in raw_pred]))
    params = _clamp_params(raw_params, technology)
    ranges = _param_ranges(models.stage2b, X2b, params)
    scores = _compute_scores(technology, material, params)

    # ── Alternative technology (medium / low tech confidence) ─────────────────
    alternative = None
    if t_tier in ("medium", "low") and len(tech_classes) == 2:
        alt_idx = 1 - tech_idx
        alt_tech = tech_classes[alt_idx]
        alt_tech_conf = float(tech_proba[alt_idx])

        alt_tech_enc = _encode_label(models.label_encoders, "technology", alt_tech, alt_idx)
        X_alt = np.hstack([X, [[alt_tech_enc]]])

        alt_mat_proba: np.ndarray = models.stage2a.predict_proba(X_alt)[0]
        alt_mat_idx = int(np.argmax(alt_mat_proba))
        alt_mat = mat_classes[alt_mat_idx]

        alt_mat_enc = _encode_label(models.label_encoders, "material", alt_mat, alt_mat_idx)
        X_alt2b = np.hstack([X_alt, [[alt_mat_enc]]])
        alt_raw = models.stage2b.predict(X_alt2b)[0]
        alt_params_raw = dict(zip(_PARAM_NAMES, [float(v) for v in alt_raw]))
        alt_params = _clamp_params(alt_params_raw, alt_tech)
        alt_scores = _compute_scores(alt_tech, alt_mat, alt_params)

        alternative = {
            "technology": alt_tech,
            "material": alt_mat,
            "confidence": alt_tech_conf,
            **alt_scores,
        }

    # ── Clarification question ────────────────────────────────────────────────
    needs_clarification = False
    clarification_question: str | None = None
    clarification_field: str | None = None

    if t_tier == "low":
        needs_clarification = True
        clarification_question, clarification_field = _clarification_for_tech_confusion()
    elif m_tier == "low":
        needs_clarification = True
        clarification_question, clarification_field = _clarification_for_material(material)

    return {
        "technology":            technology,
        "technology_confidence": tech_conf,
        "material":              material,
        "material_confidence":   mat_conf,
        "confidence_tier":       _overall_tier(t_tier, m_tier),
        "layer_height":          params["layer_height"],
        "layer_height_min":      ranges["layer_height_min"],
        "layer_height_max":      ranges["layer_height_max"],
        "infill_density":        params["infill_density"],
        "print_speed":           params["print_speed"],
        "wall_count":            params["wall_count"],
        "cooling_fan":           params["cooling_fan"],
        "support_density":       params["support_density"],
        "cost_score":            scores["cost_score"],
        "quality_score":         scores["quality_score"],
        "speed_score":           scores["speed_score"],
        "needs_clarification":   needs_clarification,
        "clarification_question": clarification_question,
        "clarification_field":   clarification_field,
        "alternative":           alternative,
    }
