"""Slicing endpoints — manual trigger, status, gcode download, cancel."""

from pathlib import Path
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.print_job import PrintJob
from app.models.slicing_job import SlicingJob
from app.models.user import User
from app.schemas.slicing import SlicingJobRead
from app.services import slicing_service
from app.workers.queue import enqueue_slice_sync

router = APIRouter(tags=["Slicing"])


def _is_admin(current_user: dict) -> bool:
    return current_user.get("role") == "admin"


def _user(db: Session, current_user: dict) -> User:
    user = db.query(User).filter(User.id == UUID(current_user["user_id"])).first()
    if user is None:
        raise HTTPException(401, "User not found")
    return user


def _get_owned_slicing_job(
    db: Session, current_user: dict, slicing_job_id: UUID
) -> SlicingJob:
    q = db.query(SlicingJob).filter(SlicingJob.id == slicing_job_id)
    if not _is_admin(current_user):
        q = q.filter(SlicingJob.user_id == UUID(current_user["user_id"]))
    sj = q.first()
    if sj is None:
        raise HTTPException(404, "Slicing job not found")
    return sj


@router.post(
    "/jobs/{job_id}/slice",
    response_model=SlicingJobRead,
    status_code=status.HTTP_201_CREATED,
)
def trigger_slice(
    job_id: UUID,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Manual trigger when auto_slice was false or a previous slice errored."""
    user = _user(db, current_user)

    pj_q = db.query(PrintJob).filter(PrintJob.id == job_id)
    if not _is_admin(current_user):
        pj_q = pj_q.filter(PrintJob.user_id == user.id)
    pj = pj_q.first()
    if pj is None:
        raise HTTPException(404, "Job not found")

    sj = slicing_service.create_slicing_job(db, print_job=pj, user=user)
    # create_slicing_job already resets {error, canceled} → queued.
    if sj.status not in {"queued"}:
        raise HTTPException(409, f"Slicing already in status '{sj.status}'")

    enqueue_slice_sync(sj.id)
    return sj


@router.get("/slicing-jobs/{slicing_job_id}", response_model=SlicingJobRead)
def get_slicing_job(
    slicing_job_id: UUID,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return _get_owned_slicing_job(db, current_user, slicing_job_id)


@router.get("/slicing-jobs/{slicing_job_id}/gcode")
def download_gcode(
    slicing_job_id: UUID,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    sj = _get_owned_slicing_job(db, current_user, slicing_job_id)
    if sj.status != "done" or not sj.gcode_path:
        raise HTTPException(409, "Gcode not available")

    p = Path(sj.gcode_path).resolve()
    allowed_root = Path(settings.GCODE_UPLOAD_DIR).resolve()
    try:
        p.relative_to(allowed_root)
    except ValueError:
        raise HTTPException(403, "Gcode path outside allowed directory")

    if not p.is_file():
        raise HTTPException(404, "Gcode file missing on disk")
    return FileResponse(
        path=str(p),
        media_type="application/octet-stream",
        filename=f"{sj.id}.gcode",
    )


@router.post(
    "/slicing-jobs/{slicing_job_id}/cancel",
    response_model=SlicingJobRead,
)
def cancel_slicing(
    slicing_job_id: UUID,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    sj = _get_owned_slicing_job(db, current_user, slicing_job_id)
    return slicing_service.cancel(db, sj)
