"""
Job service — business logic for print job lifecycle.

User isolation:
- Regular users see/modify only their own jobs.
- Admins see/modify all jobs.
- A user querying someone else's job gets 404 (not 403) — don't leak existence.

Status transitions handled here:
- submit:  → 'queued'  (then assign_pending_jobs may flip to 'scheduled')
- cancel:  queued|scheduled|printing|paused → 'canceled'   (frees printer if assigned)
- suspend: queued|scheduled        → 'paused'     (frees printer if scheduled)
- resume:  paused                  → 'queued'     (then re-run scheduler)
"""

import asyncio
import logging
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.config import settings
from app.connectors.factory import get_connector
from app.models.print_job import PrintJob
from app.models.printer import Printer
from app.models.recommendation import Recommendation
from app.models.slicing_job import SlicingJob
from app.models.stl_file import STLFile
from app.schemas.job import JobCreate
from app.schemas.slicing import JobSlicingRead
from app.services import activity_log_service, notification_triggers
from app.services.printer_service import get_decrypted_api_key
from app.services.scheduling_service import assign_pending_jobs, free_printer
from app.ws.emit import emit_job_status

logger = logging.getLogger(__name__)


# ── Internal helpers ──────────────────────────────────────────────────────────


def _is_admin(current_user: dict) -> bool:
    return current_user.get("role") == "admin"


def _user_uuid(current_user: dict) -> UUID:
    return UUID(current_user["user_id"])


def _attach_stl_names(db: Session, jobs: list[PrintJob]) -> None:
    """Batch-load STL filenames and set as transient attribute on each job.
    Pydantic JobRead (from_attributes=True) reads `stl_file_name` from this attr.
    """
    if not jobs:
        return
    stl_ids = {j.stl_file_id for j in jobs}
    rows = (
        db.query(STLFile.id, STLFile.original_filename)
        .filter(STLFile.id.in_(stl_ids))
        .all()
    )
    by_id = {row.id: row.original_filename for row in rows}
    for j in jobs:
        j.stl_file_name = by_id.get(j.stl_file_id)


def _attach_stl_name(db: Session, job: PrintJob) -> None:
    _attach_stl_names(db, [job])


def _get_owned_job_or_404(
    db: Session, current_user: dict, job_id: UUID
) -> PrintJob:
    """Fetch a job, enforcing isolation. Returns 404 (never 403) on cross-user access."""
    query = db.query(PrintJob).filter(PrintJob.id == job_id)
    if not _is_admin(current_user):
        query = query.filter(PrintJob.user_id == _user_uuid(current_user))

    job = query.first()
    if job is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Job not found"
        )
    return job


# ── Public API ────────────────────────────────────────────────────────────────


def submit_job(db: Session, current_user: dict, payload: JobCreate) -> PrintJob:
    """Create a queued job, then trigger the scheduler.

    Validates that:
      - the STL file exists and belongs to the user (admins can submit any STL)
      - the recommendation exists and belongs to the user (admins can use any)
    """
    user_id = _user_uuid(current_user)
    is_admin = _is_admin(current_user)

    # STL ownership check
    stl_query = db.query(STLFile).filter(STLFile.id == payload.stl_file_id)
    if not is_admin:
        stl_query = stl_query.filter(STLFile.user_id == user_id)
    if stl_query.first() is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="STL file not found"
        )

    # Recommendation ownership check
    rec_query = db.query(Recommendation).filter(
        Recommendation.id == payload.recommendation_id
    )
    if not is_admin:
        rec_query = rec_query.filter(Recommendation.user_id == user_id)
    rec = rec_query.first()
    if rec is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Recommendation not found"
        )

    # Reject if the recommendation hasn't produced a tech/material yet —
    # the matcher needs both to find a printer.
    if rec.technology is None or rec.material is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Recommendation has no technology/material yet — cannot submit job",
        )

    job = PrintJob(
        user_id=user_id,
        stl_file_id=payload.stl_file_id,
        recommendation_id=payload.recommendation_id,
        printer_id=payload.printer_id,
        priority=payload.priority,
        parameters_override=payload.parameters_override,
        status="queued",
    )
    db.add(job)
    db.commit()
    db.refresh(job)

    emit_job_status(job.id, status=job.status, printer_id=job.printer_id)
    try:
        notification_triggers.emit_job_submitted(
            db,
            user_id=job.user_id,
            job_id=job.id,
            job_name=f"Job #{str(job.id)[:8]}",
        )
        activity_log_service.log(
            db,
            event_type="job",
            message="Job soumis",
            actor_user_id=user_id,
            severity="info",
            target_type="job",
            target_id=job.id,
            metadata={"printer_id": str(job.printer_id) if job.printer_id else None},
        )
        db.commit()
    except Exception:
        logger.warning("submit notif failed job=%s", job.id, exc_info=True)
        db.rollback()

    # Try to schedule it immediately (and any other jobs that were waiting).
    assign_pending_jobs(db)
    db.refresh(job)
    emit_job_status(job.id, status=job.status, printer_id=job.printer_id)

    # Auto-slice (Gap 1). Fail loudly via log — DO NOT swallow silently.
    _attach_stl_name(db, job)

    if getattr(payload, "auto_slice", True) and settings.IN_APP_SLICING_ENABLED:
        from app.models.user import User as UserModel
        from app.services import slicing_service
        from app.workers.queue import enqueue_slice_sync

        user = db.query(UserModel).filter(UserModel.id == user_id).first()
        if user is not None:
            slicing_job = slicing_service.create_slicing_job(
                db, print_job=job, user=user
            )
            try:
                enqueue_slice_sync(slicing_job.id)
            except Exception as exc:
                logger.exception(
                    "auto-slice enqueue failed for slicing_job=%s: %s",
                    slicing_job.id,
                    exc,
                )

    return job


def list_jobs(
    db: Session,
    current_user: dict,
    *,
    status_filter: Optional[str] = None,
    printer_id: Optional[UUID] = None,
) -> list[PrintJob]:
    query = db.query(PrintJob)

    if not _is_admin(current_user):
        query = query.filter(PrintJob.user_id == _user_uuid(current_user))

    if status_filter is not None:
        query = query.filter(PrintJob.status == status_filter)

    if printer_id is not None:
        query = query.filter(PrintJob.printer_id == printer_id)

    jobs = query.order_by(PrintJob.submitted_at.desc()).all()
    _attach_stl_names(db, jobs)
    return jobs


def get_job(db: Session, current_user: dict, job_id: UUID) -> PrintJob:
    job = _get_owned_job_or_404(db, current_user, job_id)
    _attach_stl_name(db, job)
    return job


def get_job_slicing(db: Session, current_user: dict, job_id: UUID) -> JobSlicingRead:
    """Return slicing state for a job, enforcing the same isolation as job reads."""
    job = _get_owned_job_or_404(db, current_user, job_id)
    slicing_job = (
        db.query(SlicingJob)
        .filter(SlicingJob.print_job_id == job.id)
        .first()
    )

    if slicing_job is None:
        return JobSlicingRead(job_id=job.id)

    return JobSlicingRead(
        job_id=job.id,
        slicing_job_id=slicing_job.id,
        status=slicing_job.status,
        error_message=slicing_job.error_message,
        started_at=slicing_job.started_at,
        ended_at=slicing_job.ended_at,
        created_at=slicing_job.created_at,
        gcode_ready=slicing_job.status == "done" and bool(slicing_job.gcode_path),
    )


def cancel_job(db: Session, current_user: dict, job_id: UUID) -> PrintJob:
    """Cancel a job. Owner or admin. Stops active prints and frees the printer."""
    job = _get_owned_job_or_404(db, current_user, job_id)

    if job.status not in {"queued", "scheduled", "printing", "paused"}:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Cannot cancel job in status '{job.status}'",
        )

    was_assigned = job.status in {"scheduled", "printing"} and job.printer_id is not None
    was_printing = job.status == "printing"
    freed_printer_id = job.printer_id if was_assigned else None
    cancel_warning: str | None = None

    if was_printing and freed_printer_id is not None:
        printer = db.query(Printer).filter(Printer.id == freed_printer_id).first()
        if printer is None:
            cancel_warning = "Printer record missing; canceled locally only"
            logger.warning("cancel_job: printer %s missing for %s", freed_printer_id, job.id)
        else:
            try:
                api_key = get_decrypted_api_key(printer)
                connector = get_connector(printer, decrypted_api_key=api_key)
                canceled_on_printer = asyncio.run(connector.cancel_job())
            except Exception as exc:
                canceled_on_printer = False
                cancel_warning = f"Printer cancellation failed; canceled locally only: {exc}"
                logger.exception("cancel_job: connector cancel_job raised for %s", job.id)

            if not canceled_on_printer and cancel_warning is None:
                cancel_warning = "Printer did not accept cancellation; canceled locally only"
                logger.warning("cancel_job: connector rejected cancellation for %s", job.id)

    job.status = "canceled"
    job.ended_at = datetime.now(timezone.utc)
    job.time_left_seconds = None
    if cancel_warning is not None:
        job.error_message = cancel_warning[:1000]

    slicing_job = (
        db.query(SlicingJob)
        .filter(SlicingJob.print_job_id == job.id)
        .first()
    )
    if slicing_job is not None and slicing_job.status in {"queued", "running"}:
        slicing_job.status = "canceled"
        slicing_job.ended_at = job.ended_at

    if was_assigned:
        free_printer(db, freed_printer_id)

    db.commit()
    db.refresh(job)
    emit_job_status(
        job.id,
        status=job.status,
        printer_id=job.printer_id,
        error_message=job.error_message,
    )

    # If we freed a printer, see if any waiting job can now use it.
    if was_assigned:
        assign_pending_jobs(db)
        db.refresh(job)

    _attach_stl_name(db, job)
    return job


def suspend_job(db: Session, job_id: UUID) -> PrintJob:
    """Admin-only suspend. Caller (router) enforces admin via require_role."""
    job = db.query(PrintJob).filter(PrintJob.id == job_id).first()
    if job is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Job not found"
        )

    if job.status not in {"queued", "scheduled"}:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Cannot suspend job in status '{job.status}'",
        )

    was_scheduled = job.status == "scheduled"
    freed_printer_id = job.printer_id if was_scheduled else None

    job.status = "paused"
    job.printer_id = None  # detach so resume re-runs the matcher
    job.scheduled_at = None

    if was_scheduled:
        free_printer(db, freed_printer_id)

    db.commit()
    db.refresh(job)
    emit_job_status(job.id, status=job.status, printer_id=job.printer_id)

    if was_scheduled:
        assign_pending_jobs(db)
        db.refresh(job)

    _attach_stl_name(db, job)
    return job


def resume_job(db: Session, job_id: UUID) -> PrintJob:
    """Admin-only resume. Puts the job back in the queue and re-runs scheduler."""
    job = db.query(PrintJob).filter(PrintJob.id == job_id).first()
    if job is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Job not found"
        )

    if job.status != "paused":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Cannot resume job in status '{job.status}'",
        )

    job.status = "queued"
    db.commit()
    db.refresh(job)
    emit_job_status(job.id, status=job.status, printer_id=job.printer_id)

    assign_pending_jobs(db)
    db.refresh(job)
    emit_job_status(job.id, status=job.status, printer_id=job.printer_id)
    _attach_stl_name(db, job)
    return job
