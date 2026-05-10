"""arq worker entrypoint.

Run with: arq app.workers.worker.WorkerSettings
"""

from __future__ import annotations

import logging
from uuid import UUID

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

from app.services import slicing_service

logger = logging.getLogger(__name__)


async def slice_task(ctx: dict, slicing_job_id: str) -> None:
    db = SessionLocal()
    try:
        slicing_service.run_slice(
            db, UUID(slicing_job_id), worker_id=str(ctx.get("job_id", "arq"))
        )
    finally:
        db.close()


class WorkerSettings:
    functions = [slice_task]
    redis_settings = RedisSettings.from_dsn(settings.REDIS_URL)
    max_jobs = settings.SLICING_WORKER_CONCURRENCY
    job_timeout = settings.SLICER_TIMEOUT_SECONDS + 60
    keep_result = 3600
