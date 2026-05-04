"""Stage preparation utilities for the ml3dp cascade."""

from __future__ import annotations

from pathlib import Path
from typing import Iterable

import pandas as pd

from ml3dp.data.schema import (
    ALL_FEATURES,
    FDM_MATERIALS,
    FDM_PARAM_NAMES,
    SLA_MATERIALS,
    SLA_PARAM_NAMES,
)
from ml3dp.features.encoder import OneHotIntentEncoder, OrdinalIntentEncoder
from ml3dp.features.splits import StageSplit, make_split

FDM_PARAM_COLS: list[str] = [f"param_{name}" for name in FDM_PARAM_NAMES]
SLA_PARAM_COLS: list[str] = [f"param_{name}" for name in SLA_PARAM_NAMES]


def prepare_all_stages(
    df: pd.DataFrame,
    encoder_kind: str = "ordinal",
    seed: int = 1337,
) -> dict[str, StageSplit]:
    """Prepare all five stages of the recommendation cascade."""
    required = _dedupe_list(
        list(ALL_FEATURES) + ["technology", "material"] + FDM_PARAM_COLS + SLA_PARAM_COLS
    )
    _require_columns(df, required)

    encoder: OrdinalIntentEncoder | OneHotIntentEncoder
    if encoder_kind == "ordinal":
        encoder = OrdinalIntentEncoder()
    elif encoder_kind == "onehot":
        encoder = OneHotIntentEncoder()
    else:
        raise ValueError("encoder_kind must be 'ordinal' or 'onehot'")

    encoder.fit(df[ALL_FEATURES])
    encoded_all = encoder.transform(df[ALL_FEATURES])
    encoded_cols = list(encoded_all.columns)

    labels_cols = _dedupe_list(["technology", "material"] + FDM_PARAM_COLS + SLA_PARAM_COLS)
    labels_df = df[labels_cols]
    combined_df = encoded_all.join(labels_df)

    stage1 = make_split(
        combined_df,
        encoded_cols,
        "technology",
        "technology",
        seed=seed,
    )
    stage1.stage_name = "stage1_tech"

    fdm_df = combined_df[combined_df["technology"] == "FDM"]
    sla_df = combined_df[combined_df["technology"] == "SLA"]

    stage2_fdm = make_split(
        fdm_df,
        encoded_cols,
        "material",
        "material",
        seed=seed,
    )
    stage2_fdm.stage_name = "stage2_fdm"

    stage2_sla = make_split(
        sla_df,
        encoded_cols,
        "material",
        "material",
        seed=seed,
    )
    stage2_sla.stage_name = "stage2_sla"

    stage3_fdm_df, stage3_fdm_cols = _build_stage3_df(
        fdm_df,
        encoded_cols,
        FDM_MATERIALS,
        FDM_PARAM_COLS,
    )
    stage3_fdm = make_split(
        stage3_fdm_df,
        stage3_fdm_cols,
        FDM_PARAM_COLS,
        None,
        seed=seed,
    )
    stage3_fdm.stage_name = "stage3_fdm"

    stage3_sla_df, stage3_sla_cols = _build_stage3_df(
        sla_df,
        encoded_cols,
        SLA_MATERIALS,
        SLA_PARAM_COLS,
    )
    stage3_sla = make_split(
        stage3_sla_df,
        stage3_sla_cols,
        SLA_PARAM_COLS,
        None,
        seed=seed,
    )
    stage3_sla.stage_name = "stage3_sla"

    return {
        "stage1_tech": stage1,
        "stage2_fdm": stage2_fdm,
        "stage2_sla": stage2_sla,
        "stage3_fdm": stage3_fdm,
        "stage3_sla": stage3_sla,
    }


def summarize_splits(splits: dict[str, StageSplit]) -> pd.DataFrame:
    """Summarize split sizes and feature counts for reporting."""
    rows: list[dict[str, object]] = []
    for split in splits.values():
        target_kind = "classification" if isinstance(split.y_train, pd.Series) else "regression_multi"
        rows.append(
            {
                "stage_name": split.stage_name,
                "n_train": len(split.X_train),
                "n_val": len(split.X_val),
                "n_test": len(split.X_test),
                "n_features": len(split.feature_names),
                "target_kind": target_kind,
            }
        )
    return pd.DataFrame(rows)


def save_splits(splits: dict[str, StageSplit], out_dir: Path) -> None:
    """Persist prepared splits to parquet files under out_dir."""
    out_dir.mkdir(parents=True, exist_ok=True)
    for split in splits.values():
        stage_dir = out_dir / split.stage_name
        stage_dir.mkdir(parents=True, exist_ok=True)
        split.X_train.to_parquet(stage_dir / "X_train.parquet")
        split.X_val.to_parquet(stage_dir / "X_val.parquet")
        split.X_test.to_parquet(stage_dir / "X_test.parquet")
        _to_frame(split.y_train).to_parquet(stage_dir / "y_train.parquet")
        _to_frame(split.y_val).to_parquet(stage_dir / "y_val.parquet")
        _to_frame(split.y_test).to_parquet(stage_dir / "y_test.parquet")


def _require_columns(df: pd.DataFrame, required: Iterable[str]) -> None:
    missing = [name for name in required if name not in df.columns]
    assert not missing, f"Missing required columns: {missing}"


def _dedupe_list(values: list[str]) -> list[str]:
    return list(dict.fromkeys(values))


def _build_stage3_df(
    subset_df: pd.DataFrame,
    encoded_cols: list[str],
    materials: list[str],
    param_cols: list[str],
) -> tuple[pd.DataFrame, list[str]]:
    material_oh = _one_hot_material(subset_df["material"], materials)
    X = subset_df[encoded_cols].join(material_oh)
    stage_df = X.join(subset_df[param_cols])
    return stage_df, list(X.columns)


def _one_hot_material(series: pd.Series, materials: list[str]) -> pd.DataFrame:
    known = set(materials)
    unknown = set(series.dropna().unique()) - known
    if unknown:
        raise ValueError(f"Unknown material values: {sorted(unknown)}")
    data: dict[str, pd.Series] = {}
    for material in materials:
        column = f"material__{material}"
        data[column] = (series == material).astype(int)
    return pd.DataFrame(data, index=series.index)


def _to_frame(values: pd.Series | pd.DataFrame) -> pd.DataFrame:
    if isinstance(values, pd.Series):
        return values.to_frame()
    return values
