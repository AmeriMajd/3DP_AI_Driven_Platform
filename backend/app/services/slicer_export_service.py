"""
Generate slicer-compatible config files from a Recommendation record.

Supported slicers:
  - Cura 5+  →  .inst.cfg  (INI, importable via Marketplace > Import Profile)
  - PrusaSlicer 2+  →  .ini  (INI, importable via File > Import > Import Config)
"""

from __future__ import annotations

import configparser
import io
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from app.models.recommendation import Recommendation

# ── Internal helpers ──────────────────────────────────────────────────────────

def _bool_str(value: int | None) -> str:
    """Convert a 0/100 cooling_fan integer to a True/False string."""
    return "True" if (value or 0) > 0 else "False"


def _support_enabled(support_density: int | None) -> bool:
    return (support_density or 0) > 0


# ── Cura ─────────────────────────────────────────────────────────────────────

def to_cura_profile(rec: "Recommendation") -> tuple[bytes, str]:
    """
    Return (file_bytes, filename) for a Cura 5 .inst.cfg profile.

    The file is a standard INI that Cura recognises when imported through
    Preferences > Profiles > Import.  SLA settings are omitted since Cura
    only handles FDM.
    """
    cfg = configparser.ConfigParser()
    cfg.optionxform = str  # preserve case

    material = rec.material or "Unknown"
    technology = (rec.technology or "FDM").upper()
    profile_name = f"3DP_AI_{technology}_{material}"

    cfg["general"] = {
        "version": "4",
        "name": profile_name,
        "definition": "fdmprinter",
    }

    cfg["metadata"] = {
        "type": "quality",
        "quality_type": "normal",
        "global_quality": "True",
    }

    values: dict[str, str] = {}

    if rec.layer_height is not None:
        values["layer_height"] = f"{rec.layer_height:.3f}"
    if rec.infill_density is not None:
        values["infill_sparse_density"] = str(rec.infill_density)
    if rec.print_speed is not None:
        values["speed_print"] = str(rec.print_speed)
    if rec.wall_count is not None:
        values["wall_line_count"] = str(rec.wall_count)
    if rec.cooling_fan is not None:
        values["cool_fan_enabled"] = _bool_str(rec.cooling_fan)
        values["cool_fan_speed"] = str(rec.cooling_fan)
    if rec.support_density is not None:
        values["support_enable"] = str(_support_enabled(rec.support_density))
        if _support_enabled(rec.support_density):
            values["support_infill_rate"] = str(rec.support_density)

    cfg["values"] = values

    buf = io.StringIO()
    cfg.write(buf)
    filename = f"{profile_name}.inst.cfg"
    return buf.getvalue().encode("utf-8"), filename


# ── PrusaSlicer ───────────────────────────────────────────────────────────────

def to_prusaslicer_ini(rec: "Recommendation") -> tuple[bytes, str]:
    """
    Return (file_bytes, filename) for a PrusaSlicer 2 .ini config.

    Importable via File > Import > Import Config (or drag-and-drop onto the
    PrusaSlicer window).  SLA-specific keys are included when technology == SLA.
    """
    material = rec.material or "Unknown"
    technology = (rec.technology or "FDM").upper()
    profile_name = f"3DP_AI_{technology}_{material}"

    lines: list[str] = [
        f"# 3DP Intelligence Platform — {technology}/{material} profile",
        f"# Profile: {profile_name}",
        "",
    ]

    def add(key: str, value: str) -> None:
        lines.append(f"{key} = {value}")

    if rec.layer_height is not None:
        add("layer_height", f"{rec.layer_height:.3f}")
        # first layer slightly thicker for adhesion
        first = round(min(rec.layer_height * 1.5, 0.35), 3)
        add("first_layer_height", f"{first:.3f}")

    if rec.infill_density is not None:
        add("fill_density", f"{rec.infill_density}%")

    if rec.wall_count is not None:
        add("perimeters", str(rec.wall_count))

    if rec.print_speed is not None:
        add("perimeter_speed", str(rec.print_speed))
        add("infill_speed", str(int(rec.print_speed * 1.2)))
        add("travel_speed", "150")

    if rec.cooling_fan is not None:
        fan_on = rec.cooling_fan > 0
        add("cooling", "1" if fan_on else "0")
        add("fan_always_on", "1" if fan_on else "0")
        if fan_on:
            add("max_fan_speed", str(rec.cooling_fan))
            add("min_fan_speed", str(max(rec.cooling_fan - 20, 0)))

    if rec.support_density is not None:
        support_on = _support_enabled(rec.support_density)
        add("support_material", "1" if support_on else "0")
        if support_on:
            add("support_material_spacing", "2")
            add("support_material_threshold", "45")

    if technology == "SLA":
        add("printer_technology", "SLA")

    filename = f"{profile_name}.ini"
    content = "\n".join(lines) + "\n"
    return content.encode("utf-8"), filename