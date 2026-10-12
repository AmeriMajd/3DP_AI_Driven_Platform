"""Dedicated printer poll loop — pushes `printer.status` for ALL non-manual
printers regardless of whether they currently host a print job.

Complements `status_poll_service` which only watches `printing` jobs. This
loop catches idle/offline/error transitions on printers with no active job.

Wired to api startup. Runs forever until shutdown. Per-printer jittered to
spread connector calls. Configured via `PRINTER_POLL_INTERVAL_S` (default 5s).
"""

from __future__ import annotations

import asyncio
import logging
import random
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy.orm import Session

from app.connectors.factory import get_connector
from app.core.config import settings
from app.core.database import SessionLocal
from app.models.printer import Printer
from app.services import activity_log_service
from app.services.printer_service import get_decrypted_api_key
from app.ws.emit import emit_printer_status

logger = logging.getLogger(__name__)

_loop_task: Optional[asyncio.Task] = None


def _map_connector_state_to_db(state) -> Optional[str]:
    """Map connectors.base.PrinterState to printer_status_enum string."""
    name = getattr(state, "name", str(state)).lower()
    if name == "idle":
        return "idle"
    if name == "printing":
        return "printing"
    if name == "paused":
        return "printing"
    if name == "error":
        return "error"
    if name == "offline":
        return "offline"
    return None  # unknown — leave DB row alone


async def _poll_one(printer_id, prev_status: str) -> None:
    db: Session = SessionLocal()
    try:
        printer = db.query(Printer).filter(Printer.id == printer_id).first()
        if printer is None:
            return
        if printer.connector_type == "manual":
            return

        try:
            api_key = get_decrypted_api_key(printer)
            connector = get_connector(printer, decrypted_api_key=api_key)
            status = await connector.get_status()
        except Exception:
            logger.debug("printer_poll: get_status failed for %s", printer.id, exc_info=True)
            new_db_status = "offline"
            if printer.status != new_db_status:
                printer.status = new_db_status
                printer.last_seen_at = datetime.now(timezone.utc)
                activity_log_service.log(
                    db,
                    event_type="printer",
                    message=f"Imprimante passée hors ligne: {printer.name}",
                    severity="warning",
                    target_type="printer",
                    target_id=printer.id,
                    metadata={"prev_status": prev_status, "new_status": new_db_status},
                )
                db.commit()
                emit_printer_status(printer.id, status=new_db_status, online=False)
            return

        new_db_status = _map_connector_state_to_db(status.state)
        now = datetime.now(timezone.utc)
        changed = new_db_status is not None and new_db_status != printer.status

        printer.last_seen_at = now
        if changed:
            printer.status = new_db_status
            activity_log_service.log(
                db,
                event_type="printer",
                message=f"Statut imprimante: {prev_status} → {new_db_status}",
                severity="warning" if new_db_status in ("offline", "error") else "info",
                target_type="printer",
                target_id=printer.id,
                metadata={"prev_status": prev_status, "new_status": new_db_status},
            )
        db.commit()

        emit_printer_status(
            printer.id,
            status=printer.status,
            online=new_db_status != "offline" if new_db_status is not None else None,
        )
    finally:
        db.close()


async def _loop() -> None:
    interval = max(1, settings.PRINTER_POLL_INTERVAL_S)
    logger.info("printer_poll: starting (interval=%ss)", interval)
    while True:
        try:
            db: Session = SessionLocal()
            try:
                printers = (
                    db.query(Printer.id, Printer.status, Printer.connector_type)
                    .filter(Printer.connector_type != "manual")
                    .all()
                )
            finally:
                db.close()

            for p in printers:
                # Jitter per-printer to spread connector load.
                await asyncio.sleep(random.uniform(0, 0.5))
                try:
                    await _poll_one(p.id, p.status)
                except Exception:
                    logger.exception("printer_poll: _poll_one crashed for %s", p.id)

            await asyncio.sleep(interval)
        except asyncio.CancelledError:
            logger.info("printer_poll: stopped")
            return
        except Exception:
            logger.exception("printer_poll: outer loop crashed; sleeping before retry")
            await asyncio.sleep(interval)


async def start() -> None:
    global _loop_task
    if _loop_task is not None and not _loop_task.done():
        return
    if not settings.WEBSOCKETS_ENABLED:
        # Loop's only consumer is the WS bus; no point if disabled.
        return
    _loop_task = asyncio.create_task(_loop())


async def stop() -> None:
    global _loop_task
    if _loop_task is None:
        return
    _loop_task.cancel()
    try:
        await _loop_task
    except (asyncio.CancelledError, Exception):
        pass
    _loop_task = None
