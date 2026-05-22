"""Status polling — drives PrintJob.printing → completed/failed.

Runs from the arq worker every STATUS_POLL_INTERVAL_SECONDS. For each
PrintJob in 'printing' status, asks the connector for current state and
updates progress/time_left. Marks completed on terminal IDLE+near-100%,
failed on ERROR, and falls through on transient OFFLINE.

A separate watchdog pass marks any 'printing' row whose last_polled_at
is older than STATUS_POLL_STALE_SECONDS as failed (covers crashed worker
or connector hung indefinitely).

On completion/failure: frees the printer and drains the queue via
assign_pending_jobs so newly queued jobs get scheduled.
"""

from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy.orm import Session

from app.connectors.base import PrinterState
from app.connectors.factory import get_connector
from app.core.config import settings
from app.models.print_job import PrintJob
from app.models.printer import Printer
from app.services import notification_triggers
from app.services.printer_service import get_decrypted_api_key
from app.services.scheduling_service import assign_pending_jobs, free_printer
from app.ws.emit import emit_job_progress, emit_job_status, emit_printer_status

_PROGRESS_MILESTONES = (25, 50, 75, 100)


def _job_label(job: PrintJob) -> str:
    """Short human label for notifications. Real STL filename lookup is
    deferred to keep poll fast — the bell row's deep link carries job_id."""
    return f"Job #{str(job.id)[:8]}"

logger = logging.getLogger(__name__)


def poll_active_jobs(db: Session) -> int:
    """Poll every PrintJob in 'printing' status once. Return count polled."""
    jobs = db.query(PrintJob).filter(PrintJob.status == "printing").all()
    if not jobs:
        _run_watchdog(db)
        return 0

    terminal_count = 0
    for job in jobs:
        try:
            terminal = _poll_one(db, job)
            if terminal:
                terminal_count += 1
        except Exception:
            logger.exception("status_poll: unhandled error for PrintJob %s", job.id)
            db.rollback()

    if terminal_count:
        try:
            assign_pending_jobs(db)
        except Exception:
            logger.exception("status_poll: assign_pending_jobs failed after terminal transitions")

    _run_watchdog(db)
    return len(jobs)


def _poll_one(db: Session, job: PrintJob) -> bool:
    """Poll a single job. Return True if it reached a terminal state."""
    if job.printer_id is None:
        logger.warning("status_poll: PrintJob %s has no printer_id, marking failed", job.id)
        _mark_failed(db, job, None, "no printer assigned")
        return True

    printer = db.query(Printer).filter(Printer.id == job.printer_id).first()
    if printer is None:
        logger.error("status_poll: printer %s missing for PrintJob %s", job.printer_id, job.id)
        _mark_failed(db, job, None, "printer record missing")
        return True

    try:
        api_key = get_decrypted_api_key(printer)
        connector = get_connector(printer, decrypted_api_key=api_key)
        status = asyncio.run(connector.get_status())
    except Exception as exc:
        logger.warning("status_poll: connector get_status raised for %s: %s", job.id, exc)
        # Transient — leave last_polled_at unchanged so watchdog can fire.
        return False

    now = datetime.now(timezone.utc)

    if status.state == PrinterState.OFFLINE:
        # Transient — do not bump last_polled_at; watchdog will catch if it persists.
        return False

    prior_progress = job.progress_pct or 0

    job.last_polled_at = now
    if status.progress is not None:
        job.progress_pct = round(status.progress * 100.0, 2)
    if status.time_left_seconds is not None:
        job.time_left_seconds = int(status.time_left_seconds)

    # Progress-milestone notifications (25/50/75). The 100% milestone fires
    # from _mark_completed instead to avoid a duplicate at the boundary.
    new_progress = job.progress_pct or 0
    for ms in (25, 50, 75):
        if prior_progress < ms <= new_progress:
            try:
                notification_triggers.emit_print_progress(
                    db,
                    user_id=job.user_id,
                    job_id=job.id,
                    job_name=_job_label(job),
                    percent=ms,
                )
            except Exception:
                logger.warning(
                    "progress notif failed job=%s pct=%s", job.id, ms,
                    exc_info=True,
                )

    if status.state == PrinterState.ERROR:
        _mark_failed(db, job, printer, f"printer reported ERROR state")
        return True

    if status.state == PrinterState.IDLE:
        progress = status.progress if status.progress is not None else (job.progress_pct / 100.0)
        if progress >= settings.STATUS_POLL_COMPLETION_THRESHOLD:
            _mark_completed(db, job, printer)
            return True
        # IDLE but progress not yet near 1.0 — print may have been canceled on the printer.
        # Tolerate one stale reading by leaving status unchanged; watchdog handles persistence.
        db.commit()
        return False

    # PRINTING / PAUSED / UNKNOWN — just save the progress snapshot.
    db.commit()
    emit_job_progress(
        job.id,
        progress_pct=job.progress_pct,
        time_left_seconds=job.time_left_seconds,
    )
    if printer is not None:
        emit_printer_status(
            printer.id,
            status=printer.status,
            current_job_id=job.id,
        )
    return False


def _mark_completed(db: Session, job: PrintJob, printer: Printer | None) -> None:
    now = datetime.now(timezone.utc)
    job.status = "completed"
    job.progress_pct = 100.0
    job.ended_at = now
    if job.started_at is not None:
        delta = (now - job.started_at).total_seconds()
        job.actual_duration_s = max(int(delta), 0)
    if printer is not None:
        free_printer(db, printer.id)
    db.commit()
    emit_job_status(
        job.id, status="completed", printer_id=job.printer_id, progress_pct=100.0
    )
    if printer is not None:
        emit_printer_status(printer.id, status=printer.status)
    try:
        notification_triggers.emit_print_done(
            db,
            user_id=job.user_id,
            job_id=job.id,
            job_name=_job_label(job),
        )
        db.commit()
    except Exception:
        logger.warning("done notif failed job=%s", job.id, exc_info=True)
        db.rollback()
    logger.info("status_poll: PrintJob %s completed", job.id)


def _mark_failed(db: Session, job: PrintJob, printer: Printer | None, reason: str) -> None:
    job.status = "failed"
    job.error_message = reason[:1000]
    job.ended_at = datetime.now(timezone.utc)
    if printer is not None:
        free_printer(db, printer.id)
    emit_job_status(
        job.id,
        status="failed",
        printer_id=job.printer_id,
        error_message=job.error_message,
    )
    if printer is not None:
        emit_printer_status(printer.id, status=printer.status)
    elif job.printer_id is not None:
        free_printer(db, job.printer_id)
    db.commit()
    try:
        notification_triggers.emit_print_failed(
            db,
            user_id=job.user_id,
            job_id=job.id,
            job_name=_job_label(job),
            reason=reason,
        )
        db.commit()
    except Exception:
        logger.warning("failed notif failed job=%s", job.id, exc_info=True)
        db.rollback()
    logger.error("status_poll: PrintJob %s marked failed: %s", job.id, reason)


def _run_watchdog(db: Session) -> int:
    """Mark printing jobs whose last_polled_at is older than the stale threshold as failed."""
    cutoff = datetime.now(timezone.utc) - timedelta(seconds=settings.STATUS_POLL_STALE_SECONDS)
    stale = (
        db.query(PrintJob)
        .filter(PrintJob.status == "printing")
        .filter(PrintJob.last_polled_at.isnot(None))
        .filter(PrintJob.last_polled_at < cutoff)
        .all()
    )
    if not stale:
        return 0

    for job in stale:
        printer = (
            db.query(Printer).filter(Printer.id == job.printer_id).first()
            if job.printer_id is not None
            else None
        )
        _mark_failed(
            db,
            job,
            printer,
            f"watchdog: no successful poll for >{settings.STATUS_POLL_STALE_SECONDS}s",
        )

    try:
        assign_pending_jobs(db)
    except Exception:
        logger.exception("status_poll: assign_pending_jobs failed after watchdog")
    return len(stale)
