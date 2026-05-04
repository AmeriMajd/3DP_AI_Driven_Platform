"""
ML inference pipeline for 3D print recommendations.

3-stage cascade:
  Stage 1 (stage1_tech)          — FDM vs SLA
  Stage 2 (stage2_fdm/sla)       — material, branched on tech
  Stage 3 (stage3_fdm/sla)       — 6 slicer parameters, branched on tech

"""

from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd

logger = logging.getLogger(__name__)

MODELS_DIR = Path(__file__).parent.parent.parent / "models_ml"
META_FILE = MODELS_DIR / "cascade_meta.json"

_TECH_HIGH = 0.85
_TECH_MED = 0.60
_MAT_HIGH = 0.70
_MAT_MED = 0.45

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
    ("Resin-Std", "Resin-Eng"): (
        "Does this part need to withstand mechanical stress?",
        "strength_required",
    ),
}


# ── Singleton model holder ─────────────────────────────────────────────────────

class _MLModels:
    """Lazy-loaded singleton holding 5 models + cascade metadata."""

    _instance: "_MLModels | None" = None

    def __init__(self) -> None:
        self.stage1_tech = None
        self.stage2_fdm = None
        self.stage2_sla = None
        self.stage3_fdm = None
        self.stage3_sla = None
        self._stage2_fdm_le = None  # LabelEncoder present when stage2_fdm is xgboost
        self.meta: dict = {}
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
            import joblib

            self.stage1_tech = joblib.load(MODELS_DIR / "stage1_tech.joblib")

            # stage2_fdm is saved as a plain model or as {"model":..., "label_encoder":...}
            stage2_fdm_obj = joblib.load(MODELS_DIR / "stage2_fdm.joblib")
            if isinstance(stage2_fdm_obj, dict):
                self.stage2_fdm = stage2_fdm_obj["model"]
                self._stage2_fdm_le = stage2_fdm_obj.get("label_encoder")
            else:
                self.stage2_fdm = stage2_fdm_obj
                self._stage2_fdm_le = None

            self.stage2_sla = joblib.load(MODELS_DIR / "stage2_sla.joblib")
            self.stage3_fdm = joblib.load(MODELS_DIR / "stage3_fdm.joblib")
            self.stage3_sla = joblib.load(MODELS_DIR / "stage3_sla.joblib")

            with open(META_FILE) as f:
                self.meta = json.load(f)

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

def _build_features(geo: dict, intent: dict, meta: dict) -> np.ndarray:
    """Assemble 22-feature vector (16 geometry + 6 ordinal-encoded intent)."""
    encoders = meta["intent_encoders"]

    def ordinal(key: str, val: str) -> int:
        levels = encoders.get(key, [])
        try:
            return levels.index(val)
        except (ValueError, TypeError):
            logger.warning("Unknown value '%s' for '%s', defaulting to 0", val, key)
            return 0

    row: dict[str, Any] = {
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
        "intended_use":          ordinal("intended_use",      intent["intended_use"]),
        "surface_finish":        ordinal("surface_finish",    intent["surface_finish"]),
        "needs_flexibility":     int(bool(intent["needs_flexibility"])),
        "strength_required":     ordinal("strength_required", intent["strength_required"]),
        "budget_priority":       ordinal("budget_priority",   intent["budget_priority"]),
        "outdoor_use":           int(bool(intent["outdoor_use"])),
    }

    feature_names = meta["stage1_features"]
    return pd.DataFrame([[row[f] for f in feature_names]], columns=feature_names)


def _build_stage3_features(
    X_base: pd.DataFrame, technology: str, material: str, meta: dict
) -> pd.DataFrame:
    """Append material one-hot columns to the 22-feature base vector."""
    materials = meta["fdm_materials"] if technology == "FDM" else meta["sla_materials"]
    onehot: dict[str, list] = {f"material__{m}": [0] for m in materials}
    if material in materials:
        onehot[f"material__{material}"] = [1]
    else:
        logger.warning("Unknown material '%s' for %s one-hot", material, technology)
    return pd.concat([X_base, pd.DataFrame(onehot, index=X_base.index)], axis=1)


def _fdm_mat_classes(models: _MLModels) -> list[str]:
    """Resolve FDM material class names, handling xgboost label-encoded case."""
    if models._stage2_fdm_le is not None:
        return list(models._stage2_fdm_le.classes_)
    return list(models.stage2_fdm.classes_)


# ── Post-processing ────────────────────────────────────────────────────────────

def _map_fdm_params(raw: dict) -> dict[str, Any]:
    return {
        "layer_height":   round(raw["layer_height_mm"], 3),
        "infill_density": int(round(raw["infill_pct"])),
        "print_speed":    int(round(raw["print_speed_mm_s"])),
        "wall_count":     int(round(raw["wall_count"])),
        "cooling_fan":    int(round(raw["fan_speed_pct"])),
        "support_density": int(round(raw["support_density_pct"])),
    }


def _map_sla_params(raw: dict) -> dict[str, Any]:
    return {
        "layer_height":   round(raw["layer_height_mm"], 3),
        "infill_density": 100,
        "print_speed":    0,
        "wall_count":     0,
        "cooling_fan":    0,
        "support_density": int(round(raw["support_density_pct"])),
    }


def _compute_scores(technology: str, material: str, params: dict[str, Any]) -> dict[str, int]:
    """Derive cost / quality / speed scores (0–100) from predicted parameters."""
    cost = 35 if technology == "SLA" else 75
    cost += {"PLA": 10, "PETG": 0, "ABS": -5, "TPU": -10,
             "Resin-Std": 0, "Resin-Eng": -10}.get(material, 0)
    cost += int((100 - params["infill_density"]) * 0.10)
    cost = max(10, min(100, cost))

    lh = params["layer_height"]
    if technology == "SLA":
        quality = int(90 + (0.10 - lh) / 0.05 * 5)
    else:
        quality = int(95 - (lh - 0.05) / 0.30 * 40)
    quality += (params["wall_count"] - 2) * 3
    quality = max(20, min(100, quality))

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


def _clarification_for_material(material: str) -> tuple[str, str] | tuple[None, None]:
    for (m1, m2), (q, f) in _CLARIFICATIONS.items():
        if material in (m1, m2):
            return q, f
    return None, None


# ── Public inference function ──────────────────────────────────────────────────

def predict(geo: dict, intent: dict) -> dict[str, Any]:
    """
    Run the 3-stage cascade and return a result dict whose keys map 1-to-1
    with the fields written by recommendation_service.create_recommendation().
    """
    models = _MLModels.get()
    models.load()
    meta = models.meta

    X = _build_features(geo, intent, meta)

    # Stage 1 — Technology
    tech_proba = models.stage1_tech.predict_proba(X)[0]
    tech_classes = list(models.stage1_tech.classes_)
    tech_idx = int(np.argmax(tech_proba))
    technology = tech_classes[tech_idx]
    tech_conf = float(tech_proba[tech_idx])
    t_tier = _tech_tier(tech_conf)

    # Stage 2 — Material (branched on technology)
    if technology == "FDM":
        mat_proba = models.stage2_fdm.predict_proba(X)[0]
        mat_classes = _fdm_mat_classes(models)
    else:
        mat_proba = models.stage2_sla.predict_proba(X)[0]
        mat_classes = list(models.stage2_sla.classes_)

    mat_idx = int(np.argmax(mat_proba))
    material = mat_classes[mat_idx]
    mat_conf = float(mat_proba[mat_idx])
    m_tier = _mat_tier(mat_conf)

    # Stage 3 — Parameters (branched on technology)
    X3 = _build_stage3_features(X, technology, material, meta)
    if technology == "FDM":
        param_pred = models.stage3_fdm.predict(X3)[0]
        param_names = meta["fdm_param_names"]
        param_ranges = meta["fdm_param_ranges"]
    else:
        param_pred = models.stage3_sla.predict(X3)[0]
        param_names = meta["sla_param_names"]
        param_ranges = meta["sla_param_ranges"]

    raw_params: dict[str, float] = {}
    for name, value in zip(param_names, param_pred):
        lo, hi = param_ranges[name]
        raw_params[name] = float(np.clip(value, lo, hi))

    params = _map_fdm_params(raw_params) if technology == "FDM" else _map_sla_params(raw_params)
    scores = _compute_scores(technology, material, params)

    # Alternative recommendation (medium / low tech confidence)
    alternative = None
    if t_tier in ("medium", "low") and len(tech_classes) == 2:
        alt_idx = 1 - tech_idx
        alt_tech = tech_classes[alt_idx]
        alt_conf = float(tech_proba[alt_idx])

        if alt_tech == "FDM":
            alt_mat_proba = models.stage2_fdm.predict_proba(X)[0]
            alt_mat_classes = _fdm_mat_classes(models)
        else:
            alt_mat_proba = models.stage2_sla.predict_proba(X)[0]
            alt_mat_classes = list(models.stage2_sla.classes_)

        alt_mat = alt_mat_classes[int(np.argmax(alt_mat_proba))]
        X3_alt = _build_stage3_features(X, alt_tech, alt_mat, meta)

        if alt_tech == "FDM":
            alt_pred = models.stage3_fdm.predict(X3_alt)[0]
            alt_names = meta["fdm_param_names"]
            alt_ranges = meta["fdm_param_ranges"]
        else:
            alt_pred = models.stage3_sla.predict(X3_alt)[0]
            alt_names = meta["sla_param_names"]
            alt_ranges = meta["sla_param_ranges"]

        alt_raw: dict[str, float] = {}
        for name, value in zip(alt_names, alt_pred):
            lo, hi = alt_ranges[name]
            alt_raw[name] = float(np.clip(value, lo, hi))

        alt_params = _map_fdm_params(alt_raw) if alt_tech == "FDM" else _map_sla_params(alt_raw)
        alt_scores = _compute_scores(alt_tech, alt_mat, alt_params)
        alternative = {
            "technology": alt_tech,
            "material": alt_mat,
            "confidence": alt_conf,
            **alt_params,
            **alt_scores,
        }

    # Clarification question (low confidence triggers)
    needs_clarification = False
    clarification_question: str | None = None
    clarification_field: str | None = None

    if t_tier == "low":
        needs_clarification = True
        clarification_question, clarification_field = _CLARIFICATIONS[("FDM", "SLA")]
    elif m_tier == "low":
        needs_clarification = True
        clarification_question, clarification_field = _clarification_for_material(material)

    return {
        "technology":             technology,
        "technology_confidence":  tech_conf,
        "material":               material,
        "material_confidence":    mat_conf,
        "confidence_tier":        _overall_tier(t_tier, m_tier),
        "layer_height":           params["layer_height"],
        "layer_height_min":       None,
        "layer_height_max":       None,
        "infill_density":         params["infill_density"],
        "print_speed":            params["print_speed"],
        "wall_count":             params["wall_count"],
        "cooling_fan":            params["cooling_fan"],
        "support_density":        params["support_density"],
        "cost_score":             scores["cost_score"],
        "quality_score":          scores["quality_score"],
        "speed_score":            scores["speed_score"],
        "needs_clarification":    needs_clarification,
        "clarification_question": clarification_question,
        "clarification_field":    clarification_field,
        "alternative":            alternative,
    }
