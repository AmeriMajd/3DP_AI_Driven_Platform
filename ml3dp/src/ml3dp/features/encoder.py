"""Intent encoders for ml3dp feature preparation."""

from __future__ import annotations

from typing import Any

import pandas as pd

from ml3dp.data.schema import GEOMETRY_FEATURES, INTENT_FEATURES, INTENT_VALUES


def _is_bool_values(values: list[Any]) -> bool:
    return all(isinstance(value, bool) for value in values)


BOOLEAN_GEOMETRY: list[str] = [
    name for name in GEOMETRY_FEATURES if name.startswith("is_")
]
NUMERIC_GEOMETRY: list[str] = [
    name for name in GEOMETRY_FEATURES if name not in BOOLEAN_GEOMETRY
]
INTENT_BOOLEAN: list[str] = [
    name for name in INTENT_FEATURES if _is_bool_values(INTENT_VALUES[name])
]
INTENT_CATEGORICAL: list[str] = [
    name for name in INTENT_FEATURES if name not in INTENT_BOOLEAN
]


class OrdinalIntentEncoder:
    """Ordinal-encodes intent categoricals using schema order."""

    def __init__(self) -> None:
        self._category_to_int: dict[str, dict[Any, int]] = {}
        self._int_to_category: dict[str, dict[int, Any]] = {}
        self._fitted = False

    def fit(self, df: pd.DataFrame) -> "OrdinalIntentEncoder":
        """Learn categorical mappings from the schema."""
        del df
        self._category_to_int = {}
        self._int_to_category = {}
        for col in INTENT_CATEGORICAL:
            levels = INTENT_VALUES[col]
            mapping = {value: idx for idx, value in enumerate(levels)}
            self._category_to_int[col] = mapping
            self._int_to_category[col] = {idx: value for value, idx in mapping.items()}
        self._fitted = True
        return self

    def transform(self, df: pd.DataFrame) -> pd.DataFrame:
        """Transform categorical intent columns to ordinal codes."""
        self._ensure_fitted()
        encoded = df.copy()
        for col in INTENT_CATEGORICAL:
            self._check_known_values(encoded[col], col)
            encoded[col] = encoded[col].map(self._category_to_int[col]).astype(int)
        for col in self._boolean_columns(encoded.columns):
            encoded[col] = encoded[col].astype(int)
        return encoded

    def fit_transform(self, df: pd.DataFrame) -> pd.DataFrame:
        """Fit and transform in one step."""
        return self.fit(df).transform(df)

    def inverse_transform(self, df: pd.DataFrame) -> pd.DataFrame:
        """Reverse the ordinal encoding for categorical intent columns."""
        self._ensure_fitted()
        decoded = df.copy()
        for col in INTENT_CATEGORICAL:
            self._check_known_codes(decoded[col], col)
            decoded[col] = decoded[col].map(self._int_to_category[col])
        return decoded

    def _ensure_fitted(self) -> None:
        if not self._fitted:
            raise RuntimeError("Encoder has not been fitted yet.")

    def _boolean_columns(self, columns: list[str] | pd.Index) -> list[str]:
        result: list[str] = []
        for col in list(columns):
            if col in BOOLEAN_GEOMETRY or col in INTENT_BOOLEAN:
                result.append(col)
        return result

    def _check_known_values(self, series: pd.Series, col: str) -> None:
        known = set(self._category_to_int[col])
        unknown = set(series.dropna().unique()) - known
        if unknown:
            raise ValueError(f"Unknown values for {col}: {sorted(unknown)}")

    def _check_known_codes(self, series: pd.Series, col: str) -> None:
        known = set(self._int_to_category[col])
        unknown = set(series.dropna().unique()) - known
        if unknown:
            raise ValueError(f"Unknown codes for {col}: {sorted(unknown)}")


class OneHotIntentEncoder:
    """One-hot encodes intent categoricals using schema order."""

    def __init__(self) -> None:
        self._categories: dict[str, list[Any]] = {}
        self._fitted = False

    def fit(self, df: pd.DataFrame) -> "OneHotIntentEncoder":
        """Store categorical levels from the schema."""
        del df
        self._categories = {col: list(INTENT_VALUES[col]) for col in INTENT_CATEGORICAL}
        self._fitted = True
        return self

    def transform(self, df: pd.DataFrame) -> pd.DataFrame:
        """Transform categorical intent columns to one-hot columns."""
        self._ensure_fitted()
        parts: list[pd.DataFrame] = []
        for col in df.columns:
            if col in INTENT_CATEGORICAL:
                parts.append(self._one_hot_series(df[col], col, self._categories[col]))
            elif col in BOOLEAN_GEOMETRY or col in INTENT_BOOLEAN:
                parts.append(df[[col]].astype(int))
            else:
                parts.append(df[[col]])
        return pd.concat(parts, axis=1)

    def fit_transform(self, df: pd.DataFrame) -> pd.DataFrame:
        """Fit and transform in one step."""
        return self.fit(df).transform(df)

    def _ensure_fitted(self) -> None:
        if not self._fitted:
            raise RuntimeError("Encoder has not been fitted yet.")

    def _one_hot_series(
        self,
        series: pd.Series,
        col: str,
        levels: list[Any],
    ) -> pd.DataFrame:
        known = set(levels)
        unknown = set(series.dropna().unique()) - known
        if unknown:
            raise ValueError(f"Unknown values for {col}: {sorted(unknown)}")
        data: dict[str, pd.Series] = {}
        for level in levels:
            column = f"{col}__{level}"
            data[column] = (series == level).astype(int)
        return pd.DataFrame(data, index=series.index)
