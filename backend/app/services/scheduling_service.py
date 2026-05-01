"""
Scheduling service — matches queued jobs to compatible idle printers.

Compatibility rules (in find_compatible_printer):
1. printer.status == "idle"
2. printer.technology == recommendation.technology  (FDM/SLA must match)
3. recommendation.material in printer.materials_supported
4. STL bounding box fits in printer build volume — SKIPPED if any
   printer.build_volume_* is null (permissive on null printer dims)

Trigger points for assign_pending_jobs:
- After POST /jobs (a new queued job appears)
- After PATCH /jobs/{id}/cancel (a printer may have been freed)
- After PATCH /jobs/{id}/resume (a paused job re-enters the queue)
"""

from datetime import datetime, timezone
from typing import Optional

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.print_job import PrintJob
from app.models.printer import Printer
from app.models.recommendation import Recommendation
from app.models.stl_file import STLFile


# ---------- Internal helpers ----------


def _bbox_fits(stl: STLFile, printer: Printer) -> bool:
    """Return True if the STL's bounding box fits in the printer's build volume.

    Permissive on nulls: if any printer dimension is null, skip the check.
    Strict on STL: if the STL hasn't been analyzed (any bbox dim null), reject.
    """
    if (
        printer.build_volume_x is None
        or printer.build_volume_y is None
        or printer.build_volume_z is None
    ):
        return True

    if stl.bbox_x_mm is None or stl.bbox_y_mm is None or stl.bbox_z_mm is None:
        return False

    return (
        stl.bbox_x_mm <= printer.build_volume_x
        and stl.bbox_y_mm <= printer.build_volume_y
        and stl.bbox_z_mm <= printer.build_volume_z
    )


def _supports_material(printer: Printer, material: str) -> bool:
    if not printer.materials_supported:
        return False
    return material in printer.materials_supported


# ---------- Public API ----------


def find_compatible_printer(db: Session, job: PrintJob) -> Optional[Printer]:
    """Return an idle printer that can run this job, or None.

    Prefers the printer with the smallest build volume that still fits
    (leaves the bigger printers free for bigger jobs). Ties broken by name.
    """
    rec = db.query(Recommendation).filter(Recommendation.id == job.recommendation_id).first()
    if rec is None or rec.technology is None or rec.material is None:
        return None

    stl = db.query(STLFile).filter(STLFile.id == job.stl_file_id).first()
    if stl is None:
        return None

    candidates = (
        db.query(Printer)
        .filter(Printer.status == "idle")
        .filter(Printer.technology == rec.technology)
        .all()
    )

    compatible = [
        p
        for p in candidates
        if _supports_material(p, rec.material) and _bbox_fits(stl, p)
    ]

    if not compatible:
        return None

    def _volume(p: Printer) -> float:
        if (
            p.build_volume_x is None
            or p.build_volume_y is None
            or p.build_volume_z is None
        ):
            # Unknown volume — sort to the end so known-fitting printers win first
            return float("inf")
        return p.build_volume_x * p.build_volume_y * p.build_volume_z

    compatible.sort(key=lambda p: (_volume(p), p.name))
    return compatible[0]


def assign_pending_jobs(db: Session) -> list[PrintJob]:
    """Walk the queue and assign every job we can to an idle printer.

    Order: priority DESC, submitted_at ASC.

    For each job:
      - Find a compatible idle printer
      - Set job.printer_id, job.status='scheduled', job.scheduled_at=now
      - Set printer.status='printing'  (real connector flip happens in Sprint 8)

    Returns the list of newly scheduled jobs.
    """
    queued = (
        db.query(PrintJob)
        .filter(PrintJob.status == "queued")
        .order_by(PrintJob.priority.desc(), PrintJob.submitted_at.asc())
        .all()
    )

    newly_scheduled: list[PrintJob] = []
    for job in queued:
        printer = find_compatible_printer(db, job)
        if printer is None:
            continue

        now = datetime.now(timezone.utc)
        job.printer_id = printer.id
        job.status = "scheduled"
        job.scheduled_at = now
        printer.status = "printing"

        # Flush so the next find_compatible_printer query sees this printer
        # as no longer idle. Without this, multiple queued jobs would all
        # match against the same printer in a single pass.
        db.flush()

        newly_scheduled.append(job)

    if newly_scheduled:
        db.commit()
        for job in newly_scheduled:
            db.refresh(job)

    return newly_scheduled


def start_scheduled_job(db: Session, job_id) -> PrintJob:
    """Stub for Sprint 8 connector integration.

    Flips status scheduled → printing and stamps started_at. The real
    connector upload (OctoPrint/PrusaLink) lands in Sprint 8.
    """
    job = db.query(PrintJob).filter(PrintJob.id == job_id).first()
    if job is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Job not found")

    if job.status != "scheduled":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Cannot start job in status '{job.status}'",
        )

    job.status = "printing"
    job.started_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(job)
    return job


def free_printer(db: Session, printer_id) -> None:
    """Set a printer back to idle. Caller is responsible for committing if needed.

    Used by job_service.cancel_job to release a printer when a scheduled
    job is canceled before it actually starts printing.
    """
    if printer_id is None:
        return
    printer = db.query(Printer).filter(Printer.id == printer_id).first()
    if printer is not None and printer.status == "printing":
        printer.status = "idle"