"""Dispatch a sliced PrintJob to its assigned printer via a connector.

Wired in after slicing succeeds. Picks up any PrintJob in `scheduled` status
whose SlicingJob is `done`, uploads the gcode to the printer, and flips the
job to `printing`. On connector failure, marks the job `failed` and frees
the printer for re-scheduling.
"""

from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timezone
from pathlib import Path
from uuid import UUID

from sqlalchemy.orm import Session

from app.connectors.base import JobSubmission
from app.connectors.factory import get_connector
from app.models.print_job import PrintJob
from app.models.printer import Printer
from app.models.slicing_job import SlicingJob
from app.models.stl_file import STLFile
from app.services.printer_service import get_decrypted_api_key
from app.services.scheduling_service import free_printer
from app.ws.emit import emit_job_status

logger = logging.getLogger(__name__)


def dispatch_to_printer(db: Session, print_job_id: UUID) -> None:
    """Send the sliced gcode to the assigned printer.

    No-op (logged) if:
      - PrintJob missing or not `scheduled`.
      - Printer missing.
      - SlicingJob missing, not `done`, or has no gcode_path.

    On connector success: PrintJob.status='printing', started_at, remote_job_id.
    On connector failure: PrintJob.status='failed', error_message, free printer.
    """
    pj = db.query(PrintJob).filter(PrintJob.id == print_job_id).first()
    if pj is None:
        logger.warning("dispatch: PrintJob %s not found", print_job_id)
        return

    if pj.status != "scheduled":
        logger.info(
            "dispatch: PrintJob %s status=%s (not scheduled), skipping",
            print_job_id,
            pj.status,
        )
        return

    if pj.printer_id is None:
        logger.warning("dispatch: PrintJob %s has no printer_id", print_job_id)
        return

    printer = db.query(Printer).filter(Printer.id == pj.printer_id).first()
    if printer is None:
        logger.error("dispatch: Printer %s missing for PrintJob %s", pj.printer_id, pj.id)
        return

    sj = (
        db.query(SlicingJob)
        .filter(SlicingJob.print_job_id == pj.id)
        .first()
    )
    if sj is None or sj.status != "done" or not sj.gcode_path:
        logger.info(
            "dispatch: PrintJob %s slice not ready (status=%s)",
            pj.id,
            sj.status if sj else "none",
        )
        return

    gcode_path = Path(sj.gcode_path)
    if not gcode_path.is_file():
        _mark_failed(db, pj, printer, "Gcode file missing on disk")
        return

    stl = db.query(STLFile).filter(STLFile.id == pj.stl_file_id).first()
    file_name = (
        f"{stl.original_filename.rsplit('.', 1)[0]}.gcode"
        if stl is not None
        else f"{pj.id}.gcode"
    )

    api_key = get_decrypted_api_key(printer)
    connector = get_connector(printer, decrypted_api_key=api_key)
    submission = JobSubmission(
        file_path=str(gcode_path),
        file_name=file_name,
        start_immediately=True,
    )

    try:
        result = asyncio.run(connector.submit_job(submission))
    except Exception as exc:
        logger.exception("dispatch: connector submit_job raised for %s", pj.id)
        _mark_failed(db, pj, printer, f"connector error: {exc}")
        return

    if not result.success:
        _mark_failed(db, pj, printer, f"printer rejected job: {result.message}")
        return

    pj.status = "printing"
    pj.started_at = datetime.now(timezone.utc)
    pj.remote_job_id = result.remote_job_id
    db.commit()
    db.refresh(pj)
    emit_job_status(pj.id, status=pj.status, printer_id=pj.printer_id)
    logger.info(
        "dispatch: PrintJob %s sent to printer %s (remote_job_id=%s)",
        pj.id,
        printer.name,
        result.remote_job_id,
    )


def _mark_failed(
    db: Session, pj: PrintJob, printer: Printer, reason: str
) -> None:
    pj.status = "failed"
    pj.error_message = reason[:1000]
    pj.ended_at = datetime.now(timezone.utc)
    free_printer(db, printer.id)
    db.commit()
    emit_job_status(
        pj.id,
        status=pj.status,
        printer_id=pj.printer_id,
        error_message=pj.error_message,
    )
    logger.error("dispatch: PrintJob %s marked failed: %s", pj.id, reason)
