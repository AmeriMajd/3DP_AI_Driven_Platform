"""Slicing job lifecycle + PrusaSlicer subprocess driver."""

from __future__ import annotations

import logging
import subprocess
import tempfile
from datetime import datetime, timedelta, timezone
from pathlib import Path
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.print_job import PrintJob
from app.models.recommendation import Recommendation
from app.models.slicing_job import SlicingJob
from app.models.stl_file import STLFile
from app.models.user import User
from app.services.slicer_profile_builder import build_prusaslicer_ini

logger = logging.getLogger(__name__)


def _stl_dir() -> Path:
    return Path(settings.STL_UPLOAD_DIR)


def _gcode_dir() -> Path:
    return Path(settings.GCODE_UPLOAD_DIR)


def _reset_for_retry(sj: SlicingJob) -> None:
    sj.status = "queued"
    sj.error_message = None
    sj.gcode_path = None
    sj.file_size_bytes = None
    sj.started_at = None
    sj.ended_at = None
    sj.worker_id = None


def create_slicing_job(
    db: Session, *, print_job: PrintJob, user: User
) -> SlicingJob:
    """Insert (or recover) a queued SlicingJob row for `print_job`. One row per print job.

    If a row already exists in {error, canceled}, reset it to queued so the worker
    re-runs cleanly. Concurrent inserts are handled via IntegrityError.
    """
    existing = (
        db.query(SlicingJob)
        .filter(SlicingJob.print_job_id == print_job.id)
        .first()
    )
    if existing is not None:
        if existing.status in {"error", "canceled"}:
            _reset_for_retry(existing)
            db.commit()
            db.refresh(existing)
        return existing

    sj = SlicingJob(
        user_id=user.id,
        print_job_id=print_job.id,
        status="queued",
    )
    db.add(sj)
    try:
        db.commit()
    except IntegrityError:
        # Concurrent insert hit the unique constraint — fetch the winner.
        db.rollback()
        sj = (
            db.query(SlicingJob)
            .filter(SlicingJob.print_job_id == print_job.id)
            .first()
        )
        if sj is None:
            raise
        return sj
    db.refresh(sj)
    return sj


def cancel(db: Session, sj: SlicingJob) -> SlicingJob:
    if sj.status not in {"queued", "running"}:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Cannot cancel slicing job in status '{sj.status}'",
        )
    sj.status = "canceled"
    sj.ended_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(sj)
    return sj


def recover_running(db: Session) -> int:
    """Reset orphaned `running` rows back to `queued` on startup.

    A row is considered orphaned if it has been running longer than
    SLICING_RUNNING_RECOVERY_SECONDS. The worker that owned it crashed.
    """
    cutoff = datetime.now(timezone.utc) - timedelta(
        seconds=settings.SLICING_RUNNING_RECOVERY_SECONDS
    )
    rows = (
        db.query(SlicingJob)
        .filter(SlicingJob.status == "running")
        .filter(SlicingJob.started_at < cutoff)
        .all()
    )
    for sj in rows:
        sj.status = "queued"
        sj.started_at = None
        sj.worker_id = None
    if rows:
        db.commit()
    return len(rows)


def run_slice(db: Session, slicing_job_id: UUID, *, worker_id: str) -> None:
    """Execute one slice run. Synchronous — meant to be called from arq worker."""
    sj = db.query(SlicingJob).filter(SlicingJob.id == slicing_job_id).first()
    if sj is None:
        logger.warning("run_slice: SlicingJob %s not found", slicing_job_id)
        return

    if sj.status == "canceled":
        logger.info("run_slice: %s canceled before run", slicing_job_id)
        return

    sj.status = "running"
    sj.worker_id = worker_id
    sj.started_at = datetime.now(timezone.utc)
    db.commit()

    try:
        gcode_path = _do_slice(sj)
        size = gcode_path.stat().st_size

        # Re-fetch to honor cancellation that arrived during the subprocess.
        db.refresh(sj)
        if sj.status == "canceled":
            logger.info(
                "run_slice: %s canceled mid-run; discarding gcode at %s",
                slicing_job_id,
                gcode_path,
            )
            gcode_path.unlink(missing_ok=True)
            return

        sj.status = "done"
        sj.gcode_path = str(gcode_path)
        sj.file_size_bytes = size
        sj.ended_at = datetime.now(timezone.utc)
        db.commit()
        logger.info(
            "run_slice: %s done, %d bytes at %s",
            slicing_job_id,
            size,
            gcode_path,
        )
    except Exception as exc:
        try:
            db.rollback()
        except Exception:
            pass
        db.refresh(sj)
        if sj.status == "canceled":
            logger.info("run_slice: %s canceled during failure path", slicing_job_id)
            return
        sj.status = "error"
        sj.error_message = str(exc)[:4000]
        sj.ended_at = datetime.now(timezone.utc)
        db.commit()
        logger.exception("run_slice: %s failed", slicing_job_id)


def _do_slice(sj: SlicingJob) -> Path:
    # Open a short session purely for input lookup. Closed before the long subprocess
    # so we don't hold a connection from the pool for 5+ minutes.
    from app.core.database import SessionLocal

    db = SessionLocal()
    try:
        pj = db.query(PrintJob).filter(PrintJob.id == sj.print_job_id).first()
        if pj is None:
            raise RuntimeError("PrintJob missing")

        rec = (
            db.query(Recommendation)
            .filter(Recommendation.id == pj.recommendation_id)
            .first()
        )
        if rec is None:
            raise RuntimeError("Recommendation missing")

        stl = db.query(STLFile).filter(STLFile.id == pj.stl_file_id).first()
        if stl is None:
            raise RuntimeError("STLFile missing")

        stl_filename = stl.stored_filename
        ini_text = build_prusaslicer_ini(rec)
    finally:
        db.close()

    stl_path = _stl_dir() / stl_filename
    if not stl_path.exists():
        raise RuntimeError(f"STL not on disk: {stl_path}")

    gcode_dir = _gcode_dir()
    gcode_dir.mkdir(parents=True, exist_ok=True)
    gcode_path = gcode_dir / f"{sj.id}.gcode"

    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".ini", delete=False, encoding="utf-8"
    ) as f:
        f.write(ini_text)
        ini_path = Path(f.name)

    stderr_log = Path(tempfile.gettempdir()) / f"prusa-slicer-{sj.id}.stderr"
    try:
        cmd = [
            settings.SLICER_PRUSA_PATH,
            "--export-gcode",
            "--output",
            str(gcode_path),
            "--load",
            str(ini_path),
            str(stl_path),
        ]
        logger.info("run_slice: cmd %s", " ".join(cmd))
        with stderr_log.open("wb") as err_f:
            result = subprocess.run(
                cmd,
                stdout=subprocess.DEVNULL,
                stderr=err_f,
                timeout=settings.SLICER_TIMEOUT_SECONDS,
            )
        if result.returncode != 0:
            raise RuntimeError(
                f"prusa-slicer exit {result.returncode}: {_tail(stderr_log)}"
            )
        if not gcode_path.exists():
            raise RuntimeError("prusa-slicer reported success but no gcode produced")
        return gcode_path
    finally:
        ini_path.unlink(missing_ok=True)
        stderr_log.unlink(missing_ok=True)


def _tail(path: Path) -> str:
    try:
        size = path.stat().st_size
        cap = settings.SLICER_STDERR_TAIL_BYTES
        with path.open("rb") as f:
            if size > cap:
                f.seek(size - cap)
            return f.read().decode("utf-8", errors="replace").strip()[:2000]
    except OSError:
        return ""
