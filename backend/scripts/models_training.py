"""
train_models.py — 3-Stage ML Model Training
Sprint 3B | 3DP Intelligence Platform

Trains:
  Stage 1:  Technology classifier (FDM vs SLA) — RandomForestClassifier
  Stage 2a: Material classifier (6 classes)    — RandomForestClassifier
  Stage 2b: Parameter regressor (6 floats)     — MultiOutputRegressor(RandomForestRegressor)

Usage:
  python scripts/train_models.py --dataset data/training_dataset.csv --output models_ml/
"""

import argparse
import warnings
from pathlib import Path

import numpy as np
import pandas as pd
import joblib
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier, RandomForestRegressor
from sklearn.multioutput import MultiOutputRegressor
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import (
    accuracy_score, f1_score, classification_report,
    mean_absolute_error, mean_squared_error, confusion_matrix,
)

warnings.filterwarnings("ignore", category=FutureWarning)


# ══════════════════════════════════════════════════════════════════════════════
# COLUMN DEFINITIONS
# ══════════════════════════════════════════════════════════════════════════════

GEOMETRY_FEATURES = [
    "volume_cm3", "surface_area_cm2", "bbox_x_mm", "bbox_y_mm", "bbox_z_mm",
    "triangle_count", "overhang_ratio", "max_overhang_angle",
    "min_wall_thickness_mm", "avg_wall_thickness_mm", "complexity_index",
    "aspect_ratio", "is_watertight", "shell_count", "com_offset_ratio",
    "flat_base_area_mm2",
]

CATEGORICAL_INTENT = [
    "intended_use", "surface_finish", "strength_required", "budget_priority",
]

BOOLEAN_INTENT = ["needs_flexibility", "outdoor_use"]

PARAM_LABELS = [
    "layer_height_mm", "infill_density_pct", "print_speed_mm_s",
    "wall_line_count", "cooling_fan_speed_pct", "support_density_pct",
]


# ══════════════════════════════════════════════════════════════════════════════
# DATA PREPARATION
# ══════════════════════════════════════════════════════════════════════════════

def prepare_data(df: pd.DataFrame):
    """
    Encode categoricals, prepare feature matrix and label vectors.
    Returns X, y_tech, y_material, y_params, encoders, feature_names.
    """
    df = df.copy()

    # Encode categorical intent features
    encoders = {}
    for col in CATEGORICAL_INTENT:
        le = LabelEncoder()
        df[col] = le.fit_transform(df[col].astype(str))
        encoders[col] = le

    # Convert booleans to int
    for col in BOOLEAN_INTENT:
        df[col] = df[col].astype(int)

    # Feature matrix
    feature_cols = GEOMETRY_FEATURES + CATEGORICAL_INTENT + BOOLEAN_INTENT
    X = df[feature_cols].values.astype(np.float64)
    feature_names = feature_cols.copy()

    # Labels
    y_tech = df["technology"].values
    y_material = df["material"].values
    y_params = df[PARAM_LABELS].values.astype(np.float64)

    return X, y_tech, y_material, y_params, encoders, feature_names


# ══════════════════════════════════════════════════════════════════════════════
# TRAINING
# ══════════════════════════════════════════════════════════════════════════════

def train_stage1(X_train, X_test, y_train, y_test):
    """Stage 1: Technology classifier — FDM vs SLA."""
    print("\n" + "=" * 60)
    print("STAGE 1 — Technology Classifier (FDM vs SLA)")
    print("=" * 60)

    model = RandomForestClassifier(
        n_estimators=200, random_state=42, n_jobs=-1, class_weight="balanced"
    )
    model.fit(X_train, y_train)

    y_pred = model.predict(X_test)
    acc = accuracy_score(y_test, y_pred)
    f1 = f1_score(y_test, y_pred, average="weighted")

    print(f"\n  Accuracy:  {acc:.4f}  {'✓' if acc > 0.90 else '✗ TARGET: >0.90'}")
    print(f"  F1-score:  {f1:.4f}  {'✓' if f1 > 0.88 else '✗ TARGET: >0.88'}")
    print(f"\n  Classification Report:")
    print(classification_report(y_test, y_pred))

    return model


def train_stage2a(X_train, X_test, y_train, y_test, y_tech_train, y_tech_test):
    """Stage 2a: Material classifier — 6 classes."""
    print("\n" + "=" * 60)
    print("STAGE 2a — Material Classifier (6 classes)")
    print("=" * 60)

    # Add technology as a feature (ground-truth during training)
    tech_encoder = LabelEncoder()
    tech_encoded_train = tech_encoder.fit_transform(y_tech_train).reshape(-1, 1)
    tech_encoded_test = tech_encoder.transform(y_tech_test).reshape(-1, 1)

    X_train_aug = np.hstack([X_train, tech_encoded_train])
    X_test_aug = np.hstack([X_test, tech_encoded_test])

    model = RandomForestClassifier(
        n_estimators=200, random_state=42, n_jobs=-1, class_weight="balanced"
    )
    model.fit(X_train_aug, y_train)

    y_pred = model.predict(X_test_aug)
    acc = accuracy_score(y_test, y_pred)
    f1 = f1_score(y_test, y_pred, average="weighted")

    print(f"\n  Accuracy:  {acc:.4f}  {'✓' if acc > 0.80 else '✗ TARGET: >0.80'}")
    print(f"  F1-score:  {f1:.4f}")
    print(f"\n  Classification Report:")
    print(classification_report(y_test, y_pred))

    return model, tech_encoder


def train_stage2b(
    X_train, X_test, y_train, y_test,
    y_tech_train, y_tech_test, y_mat_train, y_mat_test,
    tech_encoder, mat_encoder_2b
):
    """Stage 2b: Parameter regressor — 6 continuous outputs."""
    print("\n" + "=" * 60)
    print("STAGE 2b — Parameter Regressor (6 outputs)")
    print("=" * 60)

    # Add technology + material as features (ground-truth during training)
    tech_enc_train = tech_encoder.transform(y_tech_train).reshape(-1, 1)
    tech_enc_test = tech_encoder.transform(y_tech_test).reshape(-1, 1)
    mat_enc_train = mat_encoder_2b.transform(y_mat_train).reshape(-1, 1)
    mat_enc_test = mat_encoder_2b.transform(y_mat_test).reshape(-1, 1)

    X_train_aug = np.hstack([X_train, tech_enc_train, mat_enc_train])
    X_test_aug = np.hstack([X_test, tech_enc_test, mat_enc_test])

    model = MultiOutputRegressor(
        RandomForestRegressor(n_estimators=200, random_state=42, n_jobs=-1)
    )
    model.fit(X_train_aug, y_train)

    y_pred = model.predict(X_test_aug)

    print(f"\n  {'Parameter':<25s} {'MAE':>8s} {'RMSE':>8s} {'Target MAE':>12s} {'Pass':>6s}")
    print(f"  {'-'*60}")

    target_mae = {
        "layer_height_mm": 0.03,
        "infill_density_pct": 5.0,
        "print_speed_mm_s": 8.0,
        "wall_line_count": 0.5,
        "cooling_fan_speed_pct": 10.0,
        "support_density_pct": 5.0,
    }

    for i, param in enumerate(PARAM_LABELS):
        mae = mean_absolute_error(y_test[:, i], y_pred[:, i])
        rmse = np.sqrt(mean_squared_error(y_test[:, i], y_pred[:, i]))
        target = target_mae[param]
        passed = mae < target
        print(f"  {param:<25s} {mae:>8.4f} {rmse:>8.4f} {target:>12.4f} {'✓' if passed else '✗':>6s}")

    return model


# ══════════════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════════════

def main():
    parser = argparse.ArgumentParser(
        description="Train 3-stage ML models for 3DP recommendation"
    )
    parser.add_argument(
        "--dataset", type=str, default="data/training_dataset.csv",
        help="Path to training dataset CSV"
    )
    parser.add_argument(
        "--output", type=str, default="models_ml/",
        help="Output directory for .joblib model files"
    )
    args = parser.parse_args()

    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    print("3DP Intelligence Platform — Model Training")
    print("=" * 60)

    # 1. Load dataset
    print(f"\n[1/5] Loading dataset from {args.dataset}...")
    df = pd.read_csv(args.dataset)
    print(f"  ✓ Loaded {len(df)} samples, {df.shape[1]} columns")

    # 2. Prepare data
    print(f"\n[2/5] Preparing features and labels...")
    X, y_tech, y_material, y_params, encoders, feature_names = prepare_data(df)
    print(f"  ✓ Feature matrix: {X.shape}")
    print(f"  ✓ Technology classes: {np.unique(y_tech)}")
    print(f"  ✓ Material classes: {np.unique(y_material)}")

    # 3. Train/test split
    print(f"\n[3/5] Splitting data 80/20 (stratified on technology)...")
    (X_train, X_test,
     y_tech_train, y_tech_test,
     y_mat_train, y_mat_test,
     y_params_train, y_params_test) = train_test_split(
        X, y_tech, y_material, y_params,
        test_size=0.20, random_state=42, stratify=y_tech
    )
    print(f"  ✓ Train: {len(X_train)}, Test: {len(X_test)}")

    # 4. Train all models
    print(f"\n[4/5] Training models...")

    # Stage 1
    stage1 = train_stage1(X_train, X_test, y_tech_train, y_tech_test)

    # Stage 2a
    stage2a, tech_encoder_2a = train_stage2a(
        X_train, X_test, y_mat_train, y_mat_test, y_tech_train, y_tech_test
    )

    # Material encoder for Stage 2b
    mat_encoder_2b = LabelEncoder()
    mat_encoder_2b.fit(y_material)  # fit on ALL materials

    # Stage 2b
    stage2b = train_stage2b(
        X_train, X_test, y_params_train, y_params_test,
        y_tech_train, y_tech_test, y_mat_train, y_mat_test,
        tech_encoder_2a, mat_encoder_2b
    )

    # 5. Save everything
    print(f"\n[5/5] Saving models to {output_dir}/...")

    # Add the tech and material encoders to the encoders dict
    encoders["technology"] = tech_encoder_2a
    encoders["material"] = mat_encoder_2b

    joblib.dump(stage1, output_dir / "stage1_classifier.joblib")
    print(f"  ✓ stage1_classifier.joblib")

    joblib.dump(stage2a, output_dir / "stage2a_material.joblib")
    print(f"  ✓ stage2a_material.joblib")

    joblib.dump(stage2b, output_dir / "stage2b_regressor.joblib")
    print(f"  ✓ stage2b_regressor.joblib")

    joblib.dump(encoders, output_dir / "label_encoders.joblib")
    print(f"  ✓ label_encoders.joblib")

    # Save feature names for inference
    joblib.dump(feature_names, output_dir / "feature_names.joblib")
    print(f"  ✓ feature_names.joblib")

    print(f"\n{'='*60}")
    print(f"TRAINING COMPLETE")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()

