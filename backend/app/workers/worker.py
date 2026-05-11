"""arq worker entrypoint.

Run with: arq app.workers.worker.WorkerSettings
"""

from __future__ import annotations

import logging
from uuid import UUID

from arq import cron
from arq.connections import RedisSettings

from app.core.config import settings
from app.core.database import SessionLocal

# Import all models so SQLAlchemy registers them on the worker side too.
import app.models.user  # noqa: F401
import app.models.invitation  # noqa: F401
import app.models.refresh_token  # noqa: F401
import app.models.password_reset_token  # noqa: F401
import app.models.stl_file  # noqa: F401
import app.models.recommendation  # noqa: F401
import app.models.printer  # noqa: F401
import app.models.print_job  # noqa: F401
import app.models.slicing_job  # noqa: F401

from app.services import slicing_service, status_poll_service

logger = logging.getLogger(__name__)


async def slice_task(ctx: dict, slicing_job_id: str) -> None:
    import asyncio

    worker_id = str(ctx.get("job_id", "arq"))

    def _run() -> None:
        db = SessionLocal()
        try:
            slicing_service.run_slice(db, UUID(slicing_job_id), worker_id=worker_id)
        finally:
            db.close()

    await asyncio.to_thread(_run)


async def poll_status_task(ctx: dict) -> None:
    if not settings.STATUS_POLL_ENABLED:
        return
    import asyncio

    def _run() -> int:
        db = SessionLocal()
        try:
            return status_poll_service.poll_active_jobs(db)
        finally:
            db.close()

    try:
        n = await asyncio.to_thread(_run)
        if n:
            logger.info("poll_status_task: polled %d active jobs", n)
    except Exception:
        logger.exception("poll_status_task: unhandled error")


def _poll_seconds() -> set[int]:
    """Build the seconds-of-minute set for the cron based on configured interval."""
    interval = max(1, min(60, settings.STATUS_POLL_INTERVAL_SECONDS))
    return set(range(0, 60, interval))


class WorkerSettings:
    functions = [slice_task]
    cron_jobs = [
        cron(
            poll_status_task,
            second=_poll_seconds(),
            run_at_startup=False,
            unique=True,
        ),
    ]
    redis_settings = RedisSettings.from_dsn(settings.REDIS_URL)
    max_jobs = settings.SLICING_WORKER_CONCURRENCY
    job_timeout = settings.SLICER_TIMEOUT_SECONDS + 60
    keep_result = 3600
