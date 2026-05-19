"""High-level trigger helpers — preset collapse_key + rate-limit + severity
per notification type.

Phase 5 wires these into the domain code (job_service, ml pipeline,
printer poll). The presets live here so anti-spam tuning happens in one
place, not scattered across the codebase.

Conventions:
- `collapse_key` patterns scope per-entity (`job_<id>_progress` replaces
  earlier progress notifs for that same job in the FCM tray).
- `rate_limit_key` patterns target noisy event sources (defect alerts,
  rapid sensor blips). Quiet triggers (print done / failed) skip rate
  limiting since they're single events.
- All helpers are sync, take an open SQLAlchemy session, and let the
  caller own the transaction (same convention as `notification_service.emit`).
"""

from __future__ import annotations

from typing import Any, Optional
from uuid import UUID

from sqlalchemy.orm import Session

from app.services import notification_service, rate_limit


# ── Categories / types — kept as constants to avoid typos at call sites ──────

CATEGORY_PRINT = "print_job"
CATEGORY_ML = "ml_pipeline"
CATEGORY_PRINTER = "printer_health"
CATEGORY_ACCOUNT = "account_security"


# ── Print job lifecycle ──────────────────────────────────────────────────────


def emit_print_progress(
    db: Session,
    *,
    user_id: UUID,
    job_id: UUID,
    job_name: str,
    percent: int,
) -> None:
    """Progress milestones (25 / 50 / 75 / 100). Collapse key replaces the
    prior milestone in the FCM tray, so the user only ever sees the
    latest percentage. No rate-limit — milestones are sparse by design.
    """
    notification_service.emit(
        db,
        user_id=user_id,
        category=CATEGORY_PRINT,
        type_="print.progress",
        severity="info",
        title=f"Print {percent}% — {job_name}",
        body=None,
        data={"job_id": str(job_id), "progress_pct": percent},
        collapse_key=f"job_{job_id}_progress",
    )


def emit_print_done(
    db: Session,
    *,
    user_id: UUID,
    job_id: UUID,
    job_name: str,
) -> None:
    notification_service.emit(
        db,
        user_id=user_id,
        category=CATEGORY_PRINT,
        type_="print.completed",
        severity="success",
        title="Print completed",
        body=job_name,
        data={"job_id": str(job_id)},
        collapse_key=f"job_{job_id}_lifecycle",
    )


def emit_print_failed(
    db: Session,
    *,
    user_id: UUID,
    job_id: UUID,
    job_name: str,
    reason: Optional[str] = None,
) -> None:
    notification_service.emit(
        db,
        user_id=user_id,
        category=CATEGORY_PRINT,
        type_="print.failed",
        severity="error",
        title=f"Print failed — {job_name}",
        body=reason,
        data={"job_id": str(job_id)},
        collapse_key=f"job_{job_id}_lifecycle",
    )


def emit_slicing_status(
    db: Session,
    *,
    user_id: UUID,
    job_id: UUID,
    job_name: str,
    status: str,
    error: Optional[str] = None,
) -> None:
    """status ∈ {started, finished, failed}."""
    if status == "finished":
        severity, type_, title = "success", "slicing.finished", f"Slicing done — {job_name}"
    elif status == "failed":
        severity, type_, title = "error", "slicing.failed", f"Slicing failed — {job_name}"
    else:
        severity, type_, title = "info", "slicing.started", f"Slicing — {job_name}"
    notification_service.emit(
        db,
        user_id=user_id,
        category=CATEGORY_PRINT,
        type_=type_,
        severity=severity,
        title=title,
        body=error,
        data={"job_id": str(job_id)},
        collapse_key=f"job_{job_id}_slicing",
    )


# ── ML pipeline ──────────────────────────────────────────────────────────────


def emit_stl_processed(
    db: Session,
    *,
    user_id: UUID,
    stl_id: UUID,
    file_name: str,
) -> None:
    notification_service.emit(
        db,
        user_id=user_id,
        category=CATEGORY_ML,
        type_="stl.processed",
        severity="success",
        title="Model ready",
        body=file_name,
        data={"stl_id": str(stl_id)},
        collapse_key=f"stl_{stl_id}_status",
    )


def emit_defect_detected(
    db: Session,
    *,
    user_id: UUID,
    job_id: UUID,
    defect_type: str,
    detail: Optional[str] = None,
) -> None:
    """Defect alerts mid-print. Rate-limited to 1 per 5 minutes per job —
    bursts of layer-shift detections shouldn't fan out 50 alerts.
    """
    notification_service.emit(
        db,
        user_id=user_id,
        category=CATEGORY_ML,
        type_="ml.defect_detected",
        severity="warning",
        title=f"Defect detected — {defect_type}",
        body=detail,
        data={"job_id": str(job_id), "defect_type": defect_type},
        collapse_key=f"job_{job_id}_defect",
        rate_limit_key=f"defect:{job_id}",
        rate_limit_seconds=300,
    )


def emit_recommendation_ready(
    db: Session,
    *,
    user_id: UUID,
    stl_id: UUID,
    file_name: str,
    recommendation_id: UUID,
) -> None:
    notification_service.emit(
        db,
        user_id=user_id,
        category=CATEGORY_ML,
        type_="ml.recommendation_ready",
        severity="success",
        title="Recommendation ready",
        body=file_name,
        data={
            "stl_id": str(stl_id),
            "recommendation_id": str(recommendation_id),
        },
        collapse_key=f"stl_{stl_id}_recommendation",
    )


# ── Printer health ───────────────────────────────────────────────────────────


def emit_printer_status_change(
    db: Session,
    *,
    user_id: UUID,
    printer_id: UUID,
    printer_name: str,
    status: str,
) -> None:
    """Online/offline transitions. Debounced — flapping (online → offline →
    online within 30s) is suppressed because the cached value matches.
    """
    if not rate_limit.should_emit_change(
        key=f"printer_status:{printer_id}",
        value=status,
        ttl_seconds=86400,
    ):
        return

    severity = "warning" if status == "offline" else "success"
    title = (
        f"Printer offline — {printer_name}"
        if status == "offline"
        else f"Printer online — {printer_name}"
    )
    notification_service.emit(
        db,
        user_id=user_id,
        category=CATEGORY_PRINTER,
        type_=f"printer.{status}",
        severity=severity,
        title=title,
        body=None,
        data={"printer_id": str(printer_id), "status": status},
        collapse_key=f"printer_{printer_id}_status",
    )


def emit_filament_low(
    db: Session,
    *,
    user_id: UUID,
    printer_id: UUID,
    printer_name: str,
    remaining_pct: float,
) -> None:
    """Throttled to 1 alert per hour per printer — sensor can dance around
    the threshold otherwise.
    """
    notification_service.emit(
        db,
        user_id=user_id,
        category=CATEGORY_PRINTER,
        type_="printer.filament_low",
        severity="warning",
        title=f"Filament low — {printer_name}",
        body=f"~{remaining_pct:.0f}% remaining",
        data={"printer_id": str(printer_id), "remaining_pct": remaining_pct},
        collapse_key=f"printer_{printer_id}_filament",
        rate_limit_key=f"filament_low:{printer_id}",
        rate_limit_seconds=3600,
    )


# ── Account & security ───────────────────────────────────────────────────────


def emit_new_device_login(
    db: Session,
    *,
    user_id: UUID,
    device_label: str,
    ip: Optional[str] = None,
) -> None:
    notification_service.emit(
        db,
        user_id=user_id,
        category=CATEGORY_ACCOUNT,
        type_="account.new_device_login",
        severity="warning",
        title="New device login",
        body=f"{device_label}" + (f" · {ip}" if ip else ""),
        data={"device_label": device_label, "ip": ip or ""},
        collapse_key=None,  # always show — security event
    )


def emit_password_changed(
    db: Session,
    *,
    user_id: UUID,
) -> None:
    notification_service.emit(
        db,
        user_id=user_id,
        category=CATEGORY_ACCOUNT,
        type_="account.password_changed",
        severity="info",
        title="Password changed",
        body="If this wasn't you, secure your account immediately.",
        data={},
        collapse_key=None,
    )
