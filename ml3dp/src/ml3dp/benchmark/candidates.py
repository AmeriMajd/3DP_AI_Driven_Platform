"""Model family definitions per stage type."""

from sklearn.linear_model import LogisticRegression, Ridge
from sklearn.multioutput import MultiOutputRegressor
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import (
    GradientBoostingClassifier,
    GradientBoostingRegressor,
    RandomForestClassifier,
    RandomForestRegressor,
)
from lightgbm import LGBMClassifier, LGBMRegressor
from xgboost import XGBClassifier, XGBRegressor
from catboost import CatBoostClassifier, CatBoostRegressor

CLASSIFIERS: dict = {
    "logistic_regression": Pipeline([
        ("scaler", StandardScaler()),
        ("clf", LogisticRegression(max_iter=2000, class_weight="balanced")),
    ]),
    "random_forest": RandomForestClassifier(n_estimators=100, class_weight="balanced"),
    "gradient_boosting": GradientBoostingClassifier(n_estimators=100),
    "lightgbm": LGBMClassifier(n_estimators=100, class_weight="balanced", verbose=-1),
    "xgboost": XGBClassifier(n_estimators=100, eval_metric="mlogloss", verbosity=0),
    "catboost": CatBoostClassifier(iterations=100, verbose=0, auto_class_weights="Balanced"),
}

REGRESSORS: dict = {
    "ridge": MultiOutputRegressor(Pipeline([
        ("scaler", StandardScaler()),
        ("clf", Ridge()),
    ])),
    "random_forest": MultiOutputRegressor(RandomForestRegressor(n_estimators=100)),
    "gradient_boosting": MultiOutputRegressor(GradientBoostingRegressor(n_estimators=100)),
    "lightgbm": MultiOutputRegressor(LGBMRegressor(n_estimators=100, verbose=-1)),
    "xgboost": MultiOutputRegressor(XGBRegressor(n_estimators=100, verbosity=0)),
    "catboost": MultiOutputRegressor(CatBoostRegressor(iterations=100, verbose=0)),
}

# Tiebreak priority — simpler/faster wins when CIs overlap
FAMILY_PRIORITY = [
    "logistic_regression",
    "ridge",
    "random_forest",
    "gradient_boosting",
    "lightgbm",
    "xgboost",
    "catboost",
]
