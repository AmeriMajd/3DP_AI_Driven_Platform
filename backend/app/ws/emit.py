"""Service-side emit wrappers.

Each helper builds the right topic + envelope and calls `publish` (sync).
Sync-friendly so callers can use them from sync service functions, FastAPI
BackgroundTasks, and the arq worker without async ceremony.

Topic conventions (see docs/PRD_WEBSOCKETS.md §5.2):
- `job:{print_job_id}`     — job.status, job.progress, slicing.*
- `stl:{stl_file_id}`      — stl.status
- `printer:{printer_id}`   — printer.status
- `admin:jobs`             — mirror of job.status for the admin fleet view
"""

from __future__ import annotations

from typing import Any, Optional
from uuid import UUID

from app.ws.events import publish


# ── Topic builders ────────────────────────────────────────────────────────────


def _job_topic(print_job_id: UUID | str) -> str:
    return f"job:{print_job_id}"


def _stl_topic(stl_id: UUID | str) -> str:
    return f"stl:{stl_id}"


def _printer_topic(printer_id: UUID | str) -> str:
    return f"printer:{printer_id}"


# ── Emit helpers ──────────────────────────────────────────────────────────────


def emit_job_status(
    print_job_id: UUID | str,
    *,
    status: str,
    printer_id: Optional[UUID | str] = None,
    progress_pct: Optional[float] = None,
    error_message: Optional[str] = None,
    extra: Optional[dict[str, Any]] = None,
) -> None:
    data: dict[str, Any] = {"id": str(print_job_id), "status": status}
    if printer_id is not None:
        data["printer_id"] = str(printer_id)
    if progress_pct is not None:
        data["progress_pct"] = progress_pct
    if error_message is not None:
        data["error_message"] = error_message
    if extra:
        data.update(extra)
    publish(_job_topic(print_job_id), "job.status", data)
    # Mirror to admin fleet view
    publish("admin:jobs", "job.status", data)


def emit_job_progress(
    print_job_id: UUID | str,
    *,
    progress_pct: float,
    layer: Optional[int] = None,
    time_left_seconds: Optional[int] = None,
) -> None:
    data: dict[str, Any] = {
        "id": str(print_job_id),
        "progress_pct": progress_pct,
    }
    if layer is not None:
        data["layer"] = layer
    if time_left_seconds is not None:
        data["time_left_seconds"] = time_left_seconds
    publish(_job_topic(print_job_id), "job.progress", data)
    # Mirror to admin fleet view so list screens tick without per-card subscribes.
    publish("admin:jobs", "job.progress", data)


def emit_slicing_progress(
    print_job_id: UUID | str,
    *,
    percent: float,
    phase: Optional[str] = None,
) -> None:
    data: dict[str, Any] = {"percent": percent}
    if phase is not None:
        data["phase"] = phase
    publish(_job_topic(print_job_id), "slicing.progress", data)


def emit_slicing_status(
    print_job_id: UUID | str,
    *,
    status: str,
    slicing_job_id: Optional[UUID | str] = None,
    error_message: Optional[str] = None,
) -> None:
    data: dict[str, Any] = {"status": status}
    if slicing_job_id is not None:
        data["slicing_job_id"] = str(slicing_job_id)
    if error_message is not None:
        data["error_message"] = error_message
    publish(_job_topic(print_job_id), "slicing.status", data)


def emit_stl_status(
    stl_id: UUID | str,
    *,
    status: str,
    error_message: Optional[str] = None,
) -> None:
    data: dict[str, Any] = {"id": str(stl_id), "status": status}
    if error_message is not None:
        data["error_message"] = error_message
    publish(_stl_topic(stl_id), "stl.status", data)


def emit_printer_status(
    printer_id: UUID | str,
    *,
    status: str,
    online: Optional[bool] = None,
    current_job_id: Optional[UUID | str] = None,
    extra: Optional[dict[str, Any]] = None,
) -> None:
    data: dict[str, Any] = {"id": str(printer_id), "status": status}
    if online is not None:
        data["online"] = online
    if current_job_id is not None:
        data["current_job_id"] = str(current_job_id)
    if extra:
        data.update(extra)
    publish(_printer_topic(printer_id), "printer.status", data)
