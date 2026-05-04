"""Export cascade metadata for backend integration."""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from ml3dp.data.schema import (
    FDM_MATERIALS, FDM_PARAM_NAMES, FDM_PARAM_RANGES,
    GEOMETRY_FEATURES, INTENT_FEATURES, INTENT_VALUES,
    SLA_MATERIALS, SLA_PARAM_NAMES, SLA_PARAM_RANGES,
)

ALL_FEATURES = GEOMETRY_FEATURES + INTENT_FEATURES

meta = {
    "stage1_features": ALL_FEATURES,
    "stage2_features": ALL_FEATURES,
    "stage3_fdm_features": ALL_FEATURES + [f"material__{m}" for m in FDM_MATERIALS],
    "stage3_sla_features": ALL_FEATURES + [f"material__{m}" for m in SLA_MATERIALS],
    "fdm_materials": FDM_MATERIALS,
    "sla_materials": SLA_MATERIALS,
    "fdm_param_names": FDM_PARAM_NAMES,
    "sla_param_names": SLA_PARAM_NAMES,
    "fdm_param_ranges": {k: list(v) for k, v in FDM_PARAM_RANGES.items()},
    "sla_param_ranges": {k: list(v) for k, v in SLA_PARAM_RANGES.items()},
    "intent_encoders": {
        k: [str(v) if isinstance(v, bool) else v for v in vals]
        for k, vals in INTENT_VALUES.items()
        if k in ("intended_use", "surface_finish", "strength_required", "budget_priority")
    },
}

out = ROOT.parent / "backend" / "models_ml" / "cascade_meta.json"
out.parent.mkdir(parents=True, exist_ok=True)
with open(out, "w") as f:
    json.dump(meta, f, indent=2)
print(f"Wrote {out}")
