"""
src/ml3dp/data/generator.py

Synthetic dataset generator for the 3D printing recommendation system.

Produces a parquet file with one row per synthetic part. Each row contains:
    - 16 geometry features        (drawn from realistic distributions)
    - 6 intent features           (drawn from configurable priors)
    - technology, material        (from rules.py, with optional noise flips)
    - 6 FDM or 6 SLA parameters   (from rules.py, with optional noise)

Design notes
────────────
* Geometry features are NOT sampled independently. They are sampled from
  a generative model that mirrors how real STL files behave:
      volume     ~ LogNormal
      aspect     ~ TruncatedNormal in [1, 5]
      bbox       derived from volume + aspect
      tri_count  ~ LogNormal scaled by surface area
      walls      sampled with a small-thin-wall vs thick-bulky correlation
  This avoids the degenerate "1mm³ part with 50000mm bbox" rows that pure
  uniform sampling produces.

* Intent features are sampled from a *configurable* prior. The default is
  not uniform — it loosely reflects what a non-expert user submits. You can
  override per-feature priors via GeneratorConfig.intent_priors.

* Noise is applied AFTER labelling, never to the inputs of the rules.
  - Material noise: with probability `material_noise_prob`, replace the
    rule-chosen material with another material from the same technology
    drawn uniformly. Defaults to 0.03.
  - Parameter noise: each parameter is multiplied by 1 + N(0, σ) with
    a small σ (default 0.05), then clipped to range.
  - Feature noise: after labelling, each numeric geometry feature
    (except is_watertight and shell_count) is multiplied by
    1 + N(0, feature_noise_std), then clipped non-negative (ratios
    also clipped at 1). Defaults to 0.0 (off).

* Every config used to generate a dataset is saved as JSON in the same
  folder as the parquet file. This is what becomes the "dataset card".
"""

from __future__ import annotations

import json
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd

from . import rules
from .schema import (
    FDM_MATERIALS,
    SLA_MATERIALS,
    GEOMETRY_FEATURES,
    INTENT_VALUES,
)


# ─── Configuration ────────────────────────────────────────────────────────────
@dataclass
class GeneratorConfig:
    """Every knob of the generator. Saved to JSON alongside the dataset."""

    # Volume
    n_samples: int = 8000
    seed: int = 1337

    # Noise
    material_noise_prob: float = 0.03   # probability a material label is flipped
    param_noise_std: float = 0.05       # std of multiplicative param noise
    feature_noise_std: float = 0.0      # std of multiplicative geometry feature noise
    tech_noise_prob: float = 0.0        # probability a technology label is flipped

    # Intent priors — leave empty to use the defaults below
    intent_priors: dict[str, dict[Any, float]] = field(default_factory=dict)

    # Geometry sampling — log-normal volume parameters (in cm³)
    log_volume_mean: float = 2.0   # log10 cm³ — median ≈ 100 cm³
    log_volume_std:  float = 0.7

    # Aspect ratio = max(bbox) / min(bbox), drawn from N(mu, sigma) clipped to [1, 5]
    aspect_mean: float = 1.6
    aspect_std:  float = 0.6

    # Description (human-readable, free text)
    description: str = "synthetic_v3 — separable rules + tunable noise"


# Default intent priors. Loosely realistic for a non-expert user base.
_DEFAULT_INTENT_PRIORS: dict[str, dict[Any, float]] = {
    "intended_use":      {"decorative": 0.35, "functional": 0.40,
                          "mechanical": 0.15, "prototype": 0.10},
    "surface_finish":    {"rough": 0.10, "standard": 0.50,
                          "smooth": 0.30, "fine": 0.10},
    "needs_flexibility": {False: 0.85, True: 0.15},
    "strength_required": {"low": 0.30, "medium": 0.50, "high": 0.20},
    "budget_priority":   {"cost": 0.40, "balanced": 0.40, "quality": 0.20},
    "outdoor_use":       {False: 0.80, True: 0.20},
}


# ─── Public entrypoint ────────────────────────────────────────────────────────
def generate_dataset(
    config: GeneratorConfig | None = None,
    out_dir: Path | str = "data",
    name: str = "synthetic_v3",
    verbose: bool = True,
) -> pd.DataFrame:
    """Generate the synthetic dataset, save parquet + config JSON, return df.

    Set verbose=False to silence the "wrote N rows..." lines (used by tests).
    """
    cfg = config or GeneratorConfig()
    rng = np.random.default_rng(cfg.seed)

    df = _build_rows(cfg, rng)

    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    parquet_path = out_dir / f"{name}.parquet"
    config_path  = out_dir / f"{name}.config.json"

    df.to_parquet(parquet_path, index=False)
    with open(config_path, "w", encoding="utf-8") as f:
        json.dump(asdict(cfg), f, indent=2, default=_json_default)

    if verbose:
        print(f"[generator] wrote {len(df)} rows to {parquet_path}")
        print(f"[generator] config saved to {config_path}")
    return df


# ─── Row construction ─────────────────────────────────────────────────────────
def _build_rows(cfg: GeneratorConfig, rng: np.random.Generator) -> pd.DataFrame:
    n = cfg.n_samples

    # 1. Sample geometry
    geo = _sample_geometry(n, cfg, rng)

    # 2. Sample intent
    intent = _sample_intent(n, cfg, rng)

    # 3. Combine into per-row dicts
    rows: list[dict[str, Any]] = []
    for i in range(n):
        row = {**{k: geo[k][i] for k in geo}, **{k: intent[k][i] for k in intent}}

        # 4. Apply rules
        tech = rules.technology_for(row)
        if tech == "FDM":
            material = rules.fdm_material_for(row)
        else:
            material = rules.sla_material_for(row)

        # 5. Tech noise — flip technology and re-pick material from the new pool
        if rng.random() < cfg.tech_noise_prob:
            tech = "SLA" if tech == "FDM" else "FDM"
            if tech == "FDM":
                material = rules.fdm_material_for(row)
            else:
                material = rules.sla_material_for(row)

        # 7. Material noise — flip to a random other same-tech material
        if rng.random() < cfg.material_noise_prob:
            pool = FDM_MATERIALS if tech == "FDM" else SLA_MATERIALS
            alternatives = [m for m in pool if m != material]
            material = str(rng.choice(alternatives))

        # 8. Parameters
        if tech == "FDM":
            params = rules.fdm_parameters_for(row, material)
        else:
            params = rules.sla_parameters_for(row, material)

        # 9. Parameter noise (multiplicative, clipped at write time)
        params = _add_param_noise(params, tech, cfg.param_noise_std, rng)

        row["technology"] = tech
        row["material"]   = material
        for k, v in params.items():
            row[f"param_{k}"] = v
        rows.append(row)

    df = pd.DataFrame(rows)

    if cfg.feature_noise_std > 0.0:
        df = _add_feature_noise(df, cfg.feature_noise_std, rng)

    return df


# ─── Geometry sampling ────────────────────────────────────────────────────────
def _sample_geometry(
    n: int,
    cfg: GeneratorConfig,
    rng: np.random.Generator,
) -> dict[str, np.ndarray]:
    # Volume from log-normal in cm³
    log_v = rng.normal(cfg.log_volume_mean, cfg.log_volume_std, size=n)
    volume_cm3 = np.power(10.0, log_v)
    volume_cm3 = np.clip(volume_cm3, 0.5, 5000.0)  # 0.5 cm³ to 5 L — sane envelope

    # Surface area from volume — assumes a roughly cuboid part
    # SA = 6 * V^(2/3) * shape_factor; shape_factor in [1.0, 1.6]
    shape_factor = rng.uniform(1.0, 1.6, size=n)
    surface_area_cm2 = 6.0 * np.power(volume_cm3, 2.0 / 3.0) * shape_factor

    # Aspect ratio (longest dim / shortest dim), clipped to [1, 5]
    aspect_ratio = np.clip(
        rng.normal(cfg.aspect_mean, cfg.aspect_std, size=n),
        1.0, 5.0,
    )

    # Derive bbox: assume volume = bx * by * bz where bz = bx (depth = width)
    # and aspect = by / bx. So bx = (V / aspect)^(1/3); by = aspect * bx; bz = bx.
    # Convert volume cm³ → mm³ (multiply by 1000).
    volume_mm3 = volume_cm3 * 1000.0
    bbox_x_mm = np.power(volume_mm3 / aspect_ratio, 1.0 / 3.0)
    bbox_y_mm = aspect_ratio * bbox_x_mm
    bbox_z_mm = bbox_x_mm * rng.uniform(0.6, 1.4, size=n)  # mild z variation

    # Triangle count — log-normal scaled by surface area
    tri_per_cm2 = np.power(10.0, rng.normal(2.0, 0.4, size=n))   # ~100/cm² typical
    triangle_count = (tri_per_cm2 * surface_area_cm2).astype(np.int64)
    triangle_count = np.clip(triangle_count, 100, 5_000_000)

    # Overhang ratio: most parts have low overhang; 20% have heavy overhang
    overhang_ratio = np.clip(
        np.where(
            rng.random(n) < 0.20,
            rng.beta(2.0, 2.5, size=n),   # heavy-overhang regime
            rng.beta(2.0, 8.0, size=n),   # light-overhang regime
        ),
        0.0, 1.0,
    )
    max_overhang_angle = np.clip(rng.normal(45.0, 15.0, size=n), 0.0, 90.0)

    # Wall thicknesses — bimodal (thin-walled and bulky parts coexist)
    is_thin = rng.random(n) < 0.25
    min_wall_thickness_mm = np.where(
        is_thin,
        rng.uniform(0.4, 1.2, size=n),    # thin-wall regime
        rng.uniform(1.2, 4.0, size=n),    # bulky regime
    )
    avg_wall_thickness_mm = min_wall_thickness_mm * rng.uniform(1.2, 2.5, size=n)

    # Complexity index = SA / V (cm)
    complexity_index = surface_area_cm2 / volume_cm3

    # Watertight: 95% of synthetic STLs are clean
    is_watertight = (rng.random(n) < 0.95).astype(np.int64)

    # Shell count: 1 most of the time; rarely 2-3
    shell_count = np.where(
        rng.random(n) < 0.92,
        1,
        rng.integers(2, 4, size=n),
    )

    # Center-of-mass offset ratio (0 = perfectly balanced)
    com_offset_ratio = np.clip(rng.beta(2.0, 5.0, size=n), 0.0, 0.6)

    # Flat base area (mm²) — depends on bbox xy; some parts have no flat base
    has_flat_base = rng.random(n) < 0.7
    flat_base_area_mm2 = np.where(
        has_flat_base,
        bbox_x_mm * bbox_y_mm * rng.uniform(0.2, 0.9, size=n),
        bbox_x_mm * bbox_y_mm * rng.uniform(0.0, 0.1, size=n),
    )

    out = {
        "volume_cm3": volume_cm3,
        "surface_area_cm2": surface_area_cm2,
        "bbox_x_mm": bbox_x_mm,
        "bbox_y_mm": bbox_y_mm,
        "bbox_z_mm": bbox_z_mm,
        "triangle_count": triangle_count,
        "overhang_ratio": overhang_ratio,
        "max_overhang_angle": max_overhang_angle,
        "min_wall_thickness_mm": min_wall_thickness_mm,
        "avg_wall_thickness_mm": avg_wall_thickness_mm,
        "complexity_index": complexity_index,
        "aspect_ratio": aspect_ratio,
        "is_watertight": is_watertight,
        "shell_count": shell_count,
        "com_offset_ratio": com_offset_ratio,
        "flat_base_area_mm2": flat_base_area_mm2,
    }
    # Sanity: must match schema exactly
    assert set(out.keys()) == set(GEOMETRY_FEATURES), (
        f"geometry mismatch: extra={set(out)-set(GEOMETRY_FEATURES)}, "
        f"missing={set(GEOMETRY_FEATURES)-set(out)}"
    )
    return out


# ─── Intent sampling ──────────────────────────────────────────────────────────
def _sample_intent(
    n: int,
    cfg: GeneratorConfig,
    rng: np.random.Generator,
) -> dict[str, np.ndarray]:
    out: dict[str, np.ndarray] = {}
    priors = _DEFAULT_INTENT_PRIORS.copy()
    priors.update(cfg.intent_priors or {})

    for feat, allowed in INTENT_VALUES.items():
        prior = priors[feat]
        # Order must match `allowed`
        probs = np.array([prior[v] for v in allowed], dtype=float)
        probs = probs / probs.sum()
        idx = rng.choice(len(allowed), size=n, p=probs)
        out[feat] = np.array([allowed[i] for i in idx], dtype=object)
    return out


# ─── Feature noise ────────────────────────────────────────────────────────────
_SKIP_FEATURE_NOISE = {"is_watertight", "shell_count"}

# Features whose values must stay in [0, 1]
_RATIO_FEATURES = {"overhang_ratio", "com_offset_ratio"}

def _add_feature_noise(
    df: pd.DataFrame,
    sigma: float,
    rng: np.random.Generator,
) -> pd.DataFrame:
    """Apply multiplicative Gaussian noise to numeric geometry features in-place."""
    df = df.copy()
    for feat in GEOMETRY_FEATURES:
        if feat in _SKIP_FEATURE_NOISE:
            continue
        noise = rng.normal(0.0, sigma, size=len(df))
        col = df[feat].to_numpy(dtype=float)
        col = col * (1.0 + noise)
        if feat in _RATIO_FEATURES:
            col = np.clip(col, 0.0, 1.0)
        else:
            col = np.clip(col, 0.0, None)
        # Preserve integer dtype for triangle_count
        if pd.api.types.is_integer_dtype(df[feat]):
            df[feat] = col.astype(np.int64)
        else:
            df[feat] = col
    return df


# ─── Parameter noise ──────────────────────────────────────────────────────────
def _add_param_noise(
    params: dict[str, float],
    technology: str,
    sigma: float,
    rng: np.random.Generator,
) -> dict[str, float]:
    """Multiplicative noise on each parameter, then clip to schema range."""
    from .schema import FDM_PARAM_RANGES, SLA_PARAM_RANGES
    ranges = FDM_PARAM_RANGES if technology == "FDM" else SLA_PARAM_RANGES
    out: dict[str, float] = {}
    for name, value in params.items():
        noisy = value * (1.0 + rng.normal(0.0, sigma))
        lo, hi = ranges[name]
        out[name] = float(np.clip(noisy, lo, hi))
    return out


# ─── JSON helper ──────────────────────────────────────────────────────────────
def _json_default(obj: Any) -> Any:
    if isinstance(obj, (np.integer,)):
        return int(obj)
    if isinstance(obj, (np.floating,)):
        return float(obj)
    if isinstance(obj, np.ndarray):
        return obj.tolist()
    if isinstance(obj, bool):
        return bool(obj)
    raise TypeError(f"unsupported type: {type(obj)}")
