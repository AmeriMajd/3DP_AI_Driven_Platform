"""
Job service — business logic for print job lifecycle.

User isolation:
- Regular users see/modify only their own jobs.
- Admins see/modify all jobs.
- A user querying someone else's job gets 404 (not 403) — don't leak existence.

Status transitions handled here:
- submit:  → 'queued'  (then assign_pending_jobs may flip to 'scheduled')
- cancel:  queued|scheduled|paused → 'canceled'   (frees printer if scheduled)
- suspend: queued|scheduled        → 'paused'     (frees printer if scheduled)
- resume:  paused                  → 'queued'     (then re-run scheduler)
"""

from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.print_job import PrintJob
from app.models.recommendation import Recommendation
from app.models.stl_file import STLFile
from app.schemas.job import JobCreate
from app.services.scheduling_service import assign_pending_jobs, free_printer


# ── Internal helpers ──────────────────────────────────────────────────────────


def _is_admin(current_user: dict) -> bool:
    return current_user.get("role") == "admin"


def _user_uuid(current_user: dict) -> UUID:
    return UUID(current_user["user_id"])


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
        priority=payload.priority,
        parameters_override=payload.parameters_override,
        status="queued",
    )
    db.add(job)
    db.commit()
    db.refresh(job)

    # Try to schedule it immediately (and any other jobs that were waiting).
    assign_pending_jobs(db)
    db.refresh(job)
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

    return query.order_by(PrintJob.submitted_at.desc()).all()


def get_job(db: Session, current_user: dict, job_id: UUID) -> PrintJob:
    return _get_owned_job_or_404(db, current_user, job_id)


def cancel_job(db: Session, current_user: dict, job_id: UUID) -> PrintJob:
    """Cancel a job. Owner or admin. Frees the printer if scheduled."""
    job = _get_owned_job_or_404(db, current_user, job_id)

    if job.status not in {"queued", "scheduled", "paused"}:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Cannot cancel job in status '{job.status}'",
        )

    was_scheduled = job.status == "scheduled"
    freed_printer_id = job.printer_id if was_scheduled else None

    job.status = "canceled"
    job.ended_at = datetime.now(timezone.utc)

    if was_scheduled:
        free_printer(db, freed_printer_id)

    db.commit()
    db.refresh(job)

    # If we freed a printer, see if any waiting job can now use it.
    if was_scheduled:
        assign_pending_jobs(db)
        db.refresh(job)

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

    if was_scheduled:
        assign_pending_jobs(db)
        db.refresh(job)

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

    assign_pending_jobs(db)
    db.refresh(job)
    return job