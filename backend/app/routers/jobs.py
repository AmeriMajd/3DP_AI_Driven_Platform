"""
Jobs router — 6 endpoints matching the frozen contract in DEV_A brief.

Endpoint summary:
  POST   /jobs                  — submit a new job (auth)
  GET    /jobs                  — list jobs, filtered (auth: own / admin: all)
  GET    /jobs/{id}             — get one job (auth: own / admin: any)
  PATCH  /jobs/{id}/cancel      — cancel (owner or admin)
  PATCH  /jobs/{id}/suspend     — admin only
  PATCH  /jobs/{id}/resume      — admin only
"""

from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user, require_role
from app.schemas.job import JobCreate, JobRead
from app.services import job_service

router = APIRouter(prefix="/jobs", tags=["Jobs"])


@router.post(
    "",
    response_model=JobRead,
    status_code=status.HTTP_201_CREATED,
)
def submit_job(
    payload: JobCreate,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return job_service.submit_job(db, current_user, payload)


@router.get(
    "",
    response_model=list[JobRead],
)
def list_jobs(
    status_filter: Optional[str] = Query(default=None, alias="status"),
    printer_id: Optional[UUID] = Query(default=None),
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return job_service.list_jobs(
        db,
        current_user,
        status_filter=status_filter,
        printer_id=printer_id,
    )


@router.get(
    "/{job_id}",
    response_model=JobRead,
)
def get_job(
    job_id: UUID,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return job_service.get_job(db, current_user, job_id)


@router.patch(
    "/{job_id}/cancel",
    response_model=JobRead,
)
def cancel_job(
    job_id: UUID,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return job_service.cancel_job(db, current_user, job_id)


@router.patch(
    "/{job_id}/suspend",
    response_model=JobRead,
)
def suspend_job(
    job_id: UUID,
    _admin: dict = Depends(require_role("admin")),
    db: Session = Depends(get_db),
):
    return job_service.suspend_job(db, job_id)


@router.patch(
    "/{job_id}/resume",
    response_model=JobRead,
)
def resume_job(
    job_id: UUID,
    _admin: dict = Depends(require_role("admin")),
    db: Session = Depends(get_db),
):
    return job_service.resume_job(db, job_id)