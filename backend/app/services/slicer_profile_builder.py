"""Build a PrusaSlicer .ini for the worker subprocess.

Thin wrapper around the existing slicer_export_service so the export endpoint
and the slicing worker stay in sync on parameter mapping.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

from app.services.slicer_export_service import to_prusaslicer_ini

if TYPE_CHECKING:
    from app.models.recommendation import Recommendation


def build_prusaslicer_ini(rec: "Recommendation") -> str:
    """Return the .ini contents (utf-8 string) for `rec`."""
    content_bytes, _filename = to_prusaslicer_ini(rec)
    return content_bytes.decode("utf-8")
