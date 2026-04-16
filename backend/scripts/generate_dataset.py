"""
generate_dataset.py — Synthetic Training Data Generator
Sprint 3A | 3DP Intelligence Platform

Generates a complete training dataset for the 3-stage ML pipeline:
  - 16 geometry features (coherent, physically realistic)
  - 6 user intent features (weighted distributions)
  - 8 labels (technology, material, 6 slicer parameters)
  - 3 cost/time estimation columns
  - Optional: parses real .gcode.3mf files as bonus rows

Usage:
  python scripts/generate_dataset.py --output data/training_dataset.csv --synthetic-count 1800 --seed 42
  python scripts/generate_dataset.py --output data/training_dataset.csv --synthetic-count 1800 --real-gcode-dir data/real_gcode/ --seed 42
"""

import argparse
import random
import zipfile
import re
import os
import uuid
from pathlib import Path
from typing import Dict, Any, List, Optional, Tuple

import numpy as np
import pandas as pd


# ══════════════════════════════════════════════════════════════════════════════
# GEOMETRY GENERATION — coherent, physically realistic features
# ══════════════════════════════════════════════════════════════════════════════

def _rand(low: float, high: float) -> float:
    """Uniform random float in [low, high]."""
    return random.uniform(low, high)


def generate_geometry() -> Dict[str, Any]:
    """
    Generate 16 geometry features that are internally consistent.
    Starts from volume as the anchor and derives correlated features.
    """
    # Step 1: Volume (anchor) — log-uniform for good spread across magnitudes
    log_vol = _rand(np.log(0.5), np.log(2000))
    volume = np.exp(log_vol)

    # Step 2: Surface area — physically correlated with volume
    # For a cube: SA = 6 * V^(2/3). Real parts: SA/V ratio ∈ [4, 50]
    # Use wider range to get both simple and complex parts
    complexity_factor = _rand(4.0, 15.0)  # wider range → higher complexity_index for small parts
    surface_area = volume ** (2 / 3) * complexity_factor

    # Step 3: Bounding box — must contain the volume
    # Parts fill 10-60% of their bounding box
    fill_ratio = _rand(0.10, 0.55)
    bbox_volume_mm3 = (volume * 1000.0) / fill_ratio  # cm³ → mm³

    # Random proportions for the bbox
    # Use log-normal for aspect to avoid extreme values
    r1 = np.exp(_rand(-0.3, 0.3))
    r2 = np.exp(_rand(-0.3, 0.3))
    cbrt = bbox_volume_mm3 ** (1 / 3)
    bbox_x = round(cbrt * r1, 2)
    bbox_y = round(cbrt * r2, 2)
    bbox_z = round(bbox_volume_mm3 / (bbox_x * bbox_y), 2)

    # Clamp to realistic ranges
    bbox_x = max(2.0, min(400.0, bbox_x))
    bbox_y = max(2.0, min(400.0, bbox_y))
    bbox_z = max(2.0, min(400.0, bbox_z))

    # Step 4: Derived features
    complexity_index = round(surface_area / max(volume, 0.01), 4)
    dims = [bbox_x, bbox_y, bbox_z]
    aspect_ratio = round(max(dims) / max(min(dims), 0.01), 4)
    triangle_count = int(surface_area * _rand(50, 500))
    footprint = bbox_x * bbox_y
    flat_base_area = round(min(footprint * _rand(0.05, 0.4), footprint), 4)

    # Step 5: Independent features
    overhang_ratio = round(_rand(0.0, 0.8), 4)
    max_overhang_angle = round(
        overhang_ratio * 90.0 * _rand(0.8, 1.1), 2
    )
    max_overhang_angle = min(max_overhang_angle, 85.0)

    # Wall thickness — small parts tend to have thinner walls
    if volume < 10:
        min_wall = round(_rand(0.3, 3.0), 3)
    elif volume < 100:
        min_wall = round(_rand(0.5, 8.0), 3)
    else:
        min_wall = round(_rand(1.0, 20.0), 3)
    avg_wall = round(min_wall * _rand(1.2, 4.0), 3)

    is_watertight = random.random() < 0.85
    shell_count = random.choices([1, 2, 3, 4, 5], weights=[80, 10, 5, 3, 2])[0]
    com_offset = round(_rand(0.0, 0.35), 4)

    return {
        "volume_cm3": round(volume, 4),
        "surface_area_cm2": round(surface_area, 4),
        "bbox_x_mm": bbox_x,
        "bbox_y_mm": bbox_y,
        "bbox_z_mm": bbox_z,
        "triangle_count": triangle_count,
        "overhang_ratio": overhang_ratio,
        "max_overhang_angle": max_overhang_angle,
        "min_wall_thickness_mm": min_wall,
        "avg_wall_thickness_mm": avg_wall,
        "complexity_index": complexity_index,
        "aspect_ratio": aspect_ratio,
        "is_watertight": is_watertight,
        "shell_count": shell_count,
        "com_offset_ratio": com_offset,
        "flat_base_area_mm2": flat_base_area,
    }


# ══════════════════════════════════════════════════════════════════════════════
# USER INTENT GENERATION — weighted distributions
# ══════════════════════════════════════════════════════════════════════════════

def generate_user_intent() -> Dict[str, Any]:
    """Generate 6 user intent features with weighted random distributions."""
    return {
        "intended_use": random.choices(
            ["functional", "decorative", "prototype"],
            weights=[40, 25, 35]
        )[0],
        "surface_finish": random.choices(
            ["rough", "standard", "fine"],
            weights=[20, 50, 30]
        )[0],
        "needs_flexibility": random.random() < 0.10,
        "strength_required": random.choices(
            ["low", "medium", "high"],
            weights=[25, 40, 35]
        )[0],
        "budget_priority": random.choices(
            ["cost", "quality", "speed"],
            weights=[30, 45, 25]
        )[0],
        "outdoor_use": random.random() < 0.20,
    }


# ══════════════════════════════════════════════════════════════════════════════
# EXPERT RULES — determine labels from features + intent
# ══════════════════════════════════════════════════════════════════════════════

def determine_technology(geo: dict, intent: dict) -> str:
    """Apply expert rules to decide FDM vs SLA."""
    vol = geo["volume_cm3"]
    ci = geo["complexity_index"]
    mw = geo["min_wall_thickness_mm"]
    finish = intent["surface_finish"]
    budget = intent["budget_priority"]
    use = intent["intended_use"]
    flex = intent["needs_flexibility"]

    # FDM hard constraints (check first)
    if flex:
        return "FDM"
    if vol > 300:
        return "FDM"

    # SLA triggers
    if ci > 6 and vol < 50 and finish == "fine":
        return "SLA"
    if mw < 1.5 and finish == "fine":
        return "SLA"
    if use == "decorative" and finish == "fine" and vol < 50:
        return "SLA"
    if ci > 10 and vol < 30:
        return "SLA"
    if mw < 0.8 and vol < 100:
        return "SLA"
    if finish == "fine" and vol < 15 and budget == "quality":
        return "SLA"
    if use == "decorative" and finish == "fine":
        return "SLA"
    if finish == "fine" and ci > 5 and vol < 80:
        return "SLA"
    if vol < 10 and ci > 6 and finish in ("fine", "standard"):
        return "SLA"
    if mw < 1.0 and vol < 40 and finish == "standard" and budget == "quality":
        return "SLA"

    # FDM soft preferences
    if budget == "cost":
        return "FDM"
    if vol > 200:
        return "FDM"

    return "FDM"


def determine_material(tech: str, geo: dict, intent: dict) -> str:
    """Apply expert rules to decide material given technology."""
    use = intent["intended_use"]
    strength = intent["strength_required"]
    outdoor = intent["outdoor_use"]
    flex = intent["needs_flexibility"]
    budget = intent["budget_priority"]
    finish = intent["surface_finish"]
    mw = geo["min_wall_thickness_mm"]

    if tech == "FDM":
        if flex:
            return "TPU"
        if outdoor and strength in ("high", "medium"):
            return "PETG"
        if use == "functional" and strength == "high" and not outdoor:
            return "ABS"
        if use == "functional" and strength == "medium":
            return "PETG"
        if use == "functional" and outdoor:
            return "PETG"
        if budget == "cost":
            return "PLA"
        if use == "prototype" and finish == "rough":
            return "PLA"
        if use == "prototype" and strength in ("medium", "high"):
            return "PETG"
        if use == "decorative":
            return "PLA"
        return "PLA"
    else:  # SLA
        if strength == "high" and use == "functional":
            return "Resin-Engineering"
        if mw < 0.5:
            return "Resin-Engineering"
        if use == "functional" and strength == "medium" and mw < 1.0:
            return "Resin-Engineering"
        return "Resin-Standard"


def determine_parameters(
    tech: str, material: str, geo: dict, intent: dict
) -> Dict[str, float]:
    """Apply expert rules to determine the 6 slicer parameters."""
    finish = intent["surface_finish"]
    use = intent["intended_use"]
    strength = intent["strength_required"]
    budget = intent["budget_priority"]
    outdoor = intent["outdoor_use"]
    overhang = geo["overhang_ratio"]
    flat_base = geo["flat_base_area_mm2"]
    ar = geo["aspect_ratio"]

    # ── Layer height ──────────────────────────────────────────
    if tech == "SLA":
        layer_h = _rand(0.05, 0.08) if finish == "fine" else _rand(0.08, 0.12)
    else:
        if finish == "fine":
            layer_h = _rand(0.10, 0.16)
        elif finish == "standard":
            layer_h = _rand(0.16, 0.24)
        else:  # rough
            layer_h = _rand(0.24, 0.35)
        # Budget adjustments
        if budget == "speed":
            layer_h *= _rand(1.05, 1.20)
        elif budget == "quality":
            layer_h *= _rand(0.80, 0.95)
        layer_h = max(0.05, min(0.35, layer_h))

    # ── Infill density ────────────────────────────────────────
    if tech == "SLA":
        infill = 100.0
    else:
        if use == "decorative":
            infill = _rand(10, 20)
        elif use == "prototype":
            infill = _rand(15, 25)
        elif use == "functional":
            if strength == "low":
                infill = _rand(20, 30)
            elif strength == "medium":
                infill = _rand(30, 50)
            else:  # high
                infill = _rand(50, 80)
        else:
            infill = _rand(15, 30)
        if outdoor and strength == "high":
            infill = max(infill, _rand(60, 80))

    # ── Print speed ───────────────────────────────────────────
    if tech == "SLA":
        speed = 0.0  # N/A for SLA
    else:
        if material == "TPU":
            speed = _rand(25, 40)
        elif finish == "fine":
            speed = _rand(30, 50)
        elif finish == "standard":
            speed = _rand(50, 70)
        else:  # rough
            speed = _rand(70, 100)
        # High detail reduction
        if geo["complexity_index"] > 12:
            speed *= 0.80
        if budget == "speed":
            speed *= _rand(1.05, 1.15)

    # ── Wall line count ───────────────────────────────────────
    if tech == "SLA":
        walls = 0
    else:
        if use == "decorative":
            walls = 2
        elif use == "prototype":
            walls = random.choice([2, 3])
        elif use == "functional":
            if strength == "low":
                walls = random.choice([2, 3])
            elif strength == "medium":
                walls = 3
            else:  # high
                walls = random.choice([3, 4])
        else:
            walls = 2
        if outdoor:
            walls = max(walls, 4)
        if ar > 5:
            walls = min(walls + 1, 5)

    # ── Cooling fan speed ─────────────────────────────────────
    if tech == "SLA":
        fan = 0.0
    else:
        fan_map = {
            "PLA": (95, 100),
            "PETG": (50, 80),
            "ABS": (0, 30),
            "TPU": (50, 80),
        }
        lo, hi = fan_map.get(material, (80, 100))
        fan = _rand(lo, hi)

    # ── Support density ───────────────────────────────────────
    if overhang < 0.05:
        support = 0.0
    elif overhang < 0.20:
        support = _rand(5, 10)
    elif overhang < 0.40:
        support = _rand(10, 20)
    else:
        support = _rand(15, 25)
    if flat_base > 500:
        support = max(0, support - 5)

    return {
        "layer_height_mm": round(layer_h, 4),
        "infill_density_pct": round(infill, 2),
        "print_speed_mm_s": round(speed, 2),
        "wall_line_count": int(walls),
        "cooling_fan_speed_pct": round(fan, 2),
        "support_density_pct": round(support, 2),
    }


# ══════════════════════════════════════════════════════════════════════════════
# NOISE — prevent model from memorizing exact rule outputs
# ══════════════════════════════════════════════════════════════════════════════

def add_noise(params: Dict[str, float], noise_pct: float = 0.10) -> Dict[str, float]:
    """Add ±noise_pct uniform noise to continuous parameters."""
    noisy = {}
    for k, v in params.items():
        if k == "wall_line_count":
            # Integer — occasionally bump ±1
            noisy[k] = max(0, v + random.choices([-1, 0, 0, 0, 1], weights=[1, 3, 4, 3, 1])[0])
        elif v == 0.0 or v == 100.0:
            # Don't noise fixed values (SLA infill=100, fan=0, speed=0)
            noisy[k] = v
        else:
            factor = 1.0 + random.uniform(-noise_pct, noise_pct)
            noisy[k] = round(v * factor, 4)
    return noisy


# ══════════════════════════════════════════════════════════════════════════════
# COST / TIME ESTIMATION
# ══════════════════════════════════════════════════════════════════════════════

MATERIAL_DENSITIES = {
    "PLA": 1.24, "ABS": 1.04, "PETG": 1.27, "TPU": 1.21,
    "Resin-Standard": 1.10, "Resin-Engineering": 1.15,
}


def estimate_cost_time(
    tech: str, material: str, geo: dict, params: dict
) -> Dict[str, float]:
    """Estimate filament usage, print time, and layer count."""
    vol = geo["volume_cm3"]
    sa = geo["surface_area_cm2"]
    avg_wall = geo["avg_wall_thickness_mm"]
    bbox_z = geo["bbox_z_mm"]
    layer_h = params["layer_height_mm"]
    infill = params["infill_density_pct"]
    speed = params["print_speed_mm_s"]
    density = MATERIAL_DENSITIES.get(material, 1.2)

    # Total layers
    total_layers = max(1, int(bbox_z / max(layer_h, 0.01)))

    # Filament used (grams)
    if tech == "SLA":
        filament_g = vol * density
    else:
        shell_vol = sa * avg_wall / 10.0  # rough shell cm³
        infill_vol = vol * (infill / 100.0) * 0.7
        filament_g = (shell_vol + infill_vol) * density

    # Print time (seconds)
    if tech == "SLA":
        time_per_layer = 8.0 + layer_h * 100.0
        est_time = total_layers * time_per_layer
    else:
        # FDM rough estimate
        if speed > 0:
            est_time = (filament_g / (speed * 0.02)) * 3600.0
        else:
            est_time = 3600.0

    return {
        "filament_used_g": round(filament_g, 2),
        "estimated_print_time_s": round(est_time, 1),
        "total_layers": total_layers,
    }


# ══════════════════════════════════════════════════════════════════════════════
# SYNTHETIC SAMPLE GENERATION
# ══════════════════════════════════════════════════════════════════════════════

def generate_one_sample() -> Dict[str, Any]:
    """Generate a single complete training sample."""
    geo = generate_geometry()
    intent = generate_user_intent()

    tech = determine_technology(geo, intent)
    material = determine_material(tech, geo, intent)
    params = determine_parameters(tech, material, geo, intent)
    params_noisy = add_noise(params)
    cost_time = estimate_cost_time(tech, material, geo, params_noisy)

    row = {}
    row["sample_id"] = str(uuid.uuid4())[:8]
    row.update(geo)
    row.update(intent)
    row["technology"] = tech
    row["material"] = material
    row.update(params_noisy)
    row.update(cost_time)
    row["source"] = "synthetic"

    return row


def generate_synthetic_dataset(n: int, seed: int = 42) -> pd.DataFrame:
    """Generate n synthetic samples as a DataFrame."""
    random.seed(seed)
    np.random.seed(seed)

    rows = [generate_one_sample() for _ in range(n)]
    df = pd.DataFrame(rows)

    return df


# ══════════════════════════════════════════════════════════════════════════════
# REAL .gcode.3mf PARSING (optional)
# ══════════════════════════════════════════════════════════════════════════════

def _parse_gcode_content(content: str) -> Dict[str, Any]:
    """Parse G-code header comments to extract slicer settings."""
    labels = {}

    # Try Cura-style patterns first
    patterns_cura = {
        "layer_height_mm":      r"; ?layer_height\s*=\s*([\d.]+)",
        "infill_density_pct":   r"; ?infill_sparse_density\s*=\s*([\d.]+)",
        "print_speed_mm_s":     r"; ?speed_print\s*=\s*([\d.]+)",
        "wall_line_count":      r"; ?wall_line_count\s*=\s*(\d+)",
        "cooling_fan_speed_pct": r"; ?cool_fan_speed\s*=\s*([\d.]+)",
        "support_density_pct":  r"; ?support_infill_rate\s*=\s*([\d.]+)",
        "filament_used_g":      r"; ?filament used \[g\]\s*=\s*([\d.]+)",
        "estimated_print_time_s": r"; ?TIME:(\d+)",
    }

    # Try PrusaSlicer-style patterns
    patterns_prusa = {
        "layer_height_mm":      r"; ?layer_height\s*=\s*([\d.]+)",
        "infill_density_pct":   r"; ?fill_density\s*=\s*([\d.]+)%?",
        "print_speed_mm_s":     r"; ?perimeter_speed\s*=\s*([\d.]+)",
        "wall_line_count":      r"; ?perimeters\s*=\s*(\d+)",
        "cooling_fan_speed_pct": r"; ?min_fan_speed\s*=\s*([\d.]+)",
    }

    # Try Cura first, fall back to PrusaSlicer
    for key, pattern in patterns_cura.items():
        m = re.search(pattern, content, re.IGNORECASE)
        if m:
            val = m.group(1)
            labels[key] = float(val) if "." in val else int(val)

    # Fill gaps with PrusaSlicer patterns
    for key, pattern in patterns_prusa.items():
        if key not in labels:
            m = re.search(pattern, content, re.IGNORECASE)
            if m:
                val = m.group(1)
                labels[key] = float(val) if "." in val else int(val)

    # Detect material from filament_type comments
    mat_match = re.search(
        r"; ?(?:filament_type|material_type)\s*=\s*(\S+)", content, re.IGNORECASE
    )
    if mat_match:
        raw = mat_match.group(1).upper()
        mat_map = {
            "PLA": "PLA", "ABS": "ABS", "PETG": "PETG", "TPU": "TPU",
            "FLEX": "TPU", "ASA": "PETG",
        }
        labels["material"] = mat_map.get(raw, "PLA")

    return labels


def parse_real_gcode(gcode_dir: str) -> List[Dict[str, Any]]:
    """Parse .gcode.3mf files from a directory into training rows."""
    gcode_path = Path(gcode_dir)
    if not gcode_path.exists():
        return []

    rows = []
    extensions = {".3mf", ".gcode"}

    for fpath in sorted(gcode_path.iterdir()):
        if fpath.suffix.lower() not in extensions and not fpath.name.endswith(".gcode.3mf"):
            continue

        try:
            gcode_text = ""

            if fpath.suffix.lower() == ".3mf" or fpath.name.endswith(".gcode.3mf"):
                # .3mf is a ZIP archive — find .gcode inside
                with zipfile.ZipFile(fpath, "r") as zf:
                    for name in zf.namelist():
                        if name.endswith(".gcode"):
                            gcode_text = zf.read(name).decode("utf-8", errors="ignore")
                            break
            elif fpath.suffix.lower() == ".gcode":
                gcode_text = fpath.read_text(encoding="utf-8", errors="ignore")

            if not gcode_text:
                print(f"  ⚠ No G-code content found in {fpath.name}, skipping")
                continue

            labels = _parse_gcode_content(gcode_text)

            if "layer_height_mm" not in labels:
                print(f"  ⚠ Could not parse layer_height from {fpath.name}, skipping")
                continue

            # Generate coherent geometry for this real sample
            geo = generate_geometry()

            # Infer technology from material
            material = labels.get("material", "PLA")
            if material.startswith("Resin"):
                tech = "SLA"
            else:
                tech = "FDM"

            # Infer user intent from parsed settings
            lh = labels.get("layer_height_mm", 0.20)
            infill = labels.get("infill_density_pct", 20)

            if lh <= 0.12:
                finish = "fine"
            elif lh <= 0.24:
                finish = "standard"
            else:
                finish = "rough"

            if infill >= 50:
                use, strength = "functional", "high"
            elif infill >= 30:
                use, strength = "functional", "medium"
            else:
                use, strength = "prototype", "low"

            intent = {
                "intended_use": use,
                "surface_finish": finish,
                "needs_flexibility": material == "TPU",
                "strength_required": strength,
                "budget_priority": "quality",
                "outdoor_use": False,
            }

            # Build the row
            row = {"sample_id": str(uuid.uuid4())[:8]}
            row.update(geo)
            row.update(intent)
            row["technology"] = tech
            row["material"] = material

            # Use parsed labels, fill defaults for missing
            row["layer_height_mm"] = labels.get("layer_height_mm", 0.20)
            row["infill_density_pct"] = labels.get("infill_density_pct", 20.0)
            row["print_speed_mm_s"] = labels.get("print_speed_mm_s", 60.0)
            row["wall_line_count"] = int(labels.get("wall_line_count", 3))
            row["cooling_fan_speed_pct"] = labels.get("cooling_fan_speed_pct", 100.0)
            row["support_density_pct"] = labels.get("support_density_pct", 0.0)

            # Cost/time
            cost_time = estimate_cost_time(tech, material, geo, row)
            # Override with parsed values if available
            if "filament_used_g" in labels:
                cost_time["filament_used_g"] = labels["filament_used_g"]
            if "estimated_print_time_s" in labels:
                cost_time["estimated_print_time_s"] = labels["estimated_print_time_s"]

            row.update(cost_time)
            row["source"] = "real"

            rows.append(row)
            print(f"  ✓ Parsed {fpath.name} → {tech}/{material}, layer={row['layer_height_mm']}mm")

        except Exception as e:
            print(f"  ✗ Failed to parse {fpath.name}: {e}")

    return rows


# ══════════════════════════════════════════════════════════════════════════════
# VALIDATION & STATS
# ══════════════════════════════════════════════════════════════════════════════

def validate_dataset(df: pd.DataFrame) -> bool:
    """Validate the dataset for correctness."""
    issues = []

    # No NaN in feature columns
    feature_cols = [
        "volume_cm3", "surface_area_cm2", "bbox_x_mm", "bbox_y_mm", "bbox_z_mm",
        "triangle_count", "overhang_ratio", "max_overhang_angle",
        "min_wall_thickness_mm", "avg_wall_thickness_mm", "complexity_index",
        "aspect_ratio", "is_watertight", "shell_count", "com_offset_ratio",
        "flat_base_area_mm2",
    ]
    for col in feature_cols:
        if df[col].isna().any():
            issues.append(f"NaN found in feature column: {col}")

    # Label consistency: SLA should have infill=100, fan=0, walls=0
    sla = df[df["technology"] == "SLA"]
    if len(sla) > 0:
        if (sla["infill_density_pct"] != 100.0).any():
            issues.append("Some SLA rows have infill != 100")

    # Material consistency
    fdm_materials = {"PLA", "ABS", "PETG", "TPU"}
    sla_materials = {"Resin-Standard", "Resin-Engineering"}

    fdm_rows = df[df["technology"] == "FDM"]
    bad_fdm = fdm_rows[~fdm_rows["material"].isin(fdm_materials)]
    if len(bad_fdm) > 0:
        issues.append(f"FDM rows with SLA materials: {len(bad_fdm)}")

    sla_rows = df[df["technology"] == "SLA"]
    bad_sla = sla_rows[~sla_rows["material"].isin(sla_materials)]
    if len(bad_sla) > 0:
        issues.append(f"SLA rows with FDM materials: {len(bad_sla)}")

    if issues:
        print("\n⚠ VALIDATION ISSUES:")
        for i in issues:
            print(f"  - {i}")
        return False

    print("\n✓ Dataset validation passed — no issues found")
    return True


def print_stats(df: pd.DataFrame) -> None:
    """Print distribution statistics."""
    total = len(df)
    print(f"\n{'='*60}")
    print(f"DATASET STATISTICS — {total} total samples")
    print(f"{'='*60}")

    # Source breakdown
    print(f"\nSource breakdown:")
    for src, count in df["source"].value_counts().items():
        print(f"  {src}: {count} ({count/total*100:.1f}%)")

    # Technology split
    print(f"\nTechnology split:")
    for tech, count in df["technology"].value_counts().items():
        print(f"  {tech}: {count} ({count/total*100:.1f}%)")

    # Material distribution
    print(f"\nMaterial distribution:")
    for mat, count in df["material"].value_counts().sort_values(ascending=False).items():
        print(f"  {mat:25s}: {count:4d} ({count/total*100:.1f}%)")

    # Intent distributions
    print(f"\nIntended use:")
    for val, count in df["intended_use"].value_counts().items():
        print(f"  {val}: {count} ({count/total*100:.1f}%)")

    # Geometry ranges
    print(f"\nGeometry feature ranges:")
    geo_cols = ["volume_cm3", "surface_area_cm2", "complexity_index",
                "aspect_ratio", "overhang_ratio", "min_wall_thickness_mm"]
    for col in geo_cols:
        print(f"  {col:25s}: [{df[col].min():.2f}, {df[col].max():.2f}] "
              f"mean={df[col].mean():.2f}")

    # Label ranges
    print(f"\nLabel ranges (FDM only):")
    fdm = df[df["technology"] == "FDM"]
    label_cols = ["layer_height_mm", "infill_density_pct", "print_speed_mm_s",
                  "wall_line_count", "cooling_fan_speed_pct", "support_density_pct"]
    for col in label_cols:
        print(f"  {col:25s}: [{fdm[col].min():.2f}, {fdm[col].max():.2f}] "
              f"mean={fdm[col].mean():.2f}")

    print(f"\n{'='*60}")


# ══════════════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════════════

def main():
    parser = argparse.ArgumentParser(
        description="Generate synthetic training dataset for 3DP ML pipeline"
    )
    parser.add_argument(
        "--output", type=str, default="data/training_dataset.csv",
        help="Output CSV path"
    )
    parser.add_argument(
        "--synthetic-count", type=int, default=1800,
        help="Number of synthetic samples to generate"
    )
    parser.add_argument(
        "--real-gcode-dir", type=str, default=None,
        help="Directory containing real .gcode.3mf files (optional)"
    )
    parser.add_argument(
        "--seed", type=int, default=42,
        help="Random seed for reproducibility"
    )
    args = parser.parse_args()

    print("3DP Intelligence Platform — Training Data Generator")
    print("=" * 60)

    # 1. Generate synthetic data
    print(f"\n[1/3] Generating {args.synthetic_count} synthetic samples...")
    df_synthetic = generate_synthetic_dataset(args.synthetic_count, seed=args.seed)
    print(f"  ✓ Generated {len(df_synthetic)} synthetic samples")

    # 2. Parse real G-code files (optional)
    real_rows = []
    if args.real_gcode_dir:
        print(f"\n[2/3] Parsing real .gcode.3mf files from {args.real_gcode_dir}...")
        real_rows = parse_real_gcode(args.real_gcode_dir)
        print(f"  ✓ Parsed {len(real_rows)} real samples")
    else:
        print(f"\n[2/3] No real G-code directory specified, skipping")

    # 3. Combine, validate, and save
    print(f"\n[3/3] Combining and validating...")

    if real_rows:
        df_real = pd.DataFrame(real_rows)
        df = pd.concat([df_synthetic, df_real], ignore_index=True)
    else:
        df = df_synthetic

    # Shuffle
    df = df.sample(frac=1, random_state=args.seed).reset_index(drop=True)

    # Validate
    validate_dataset(df)

    # Print stats
    print_stats(df)

    # Save
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(output_path, index=False)
    print(f"\n✓ Dataset saved to {output_path}")
    print(f"  Shape: {df.shape[0]} rows × {df.shape[1]} columns")


if __name__ == "__main__":
    main()

