"""Helpers for the FastAPI process to enqueue arq jobs.

Uses a fresh pool per call so a sync caller can wrap with `asyncio.run` without
binding a cached pool to a closed event loop.
"""

from __future__ import annotations

import asyncio
from uuid import UUID

from arq import create_pool
from arq.connections import RedisSettings

from app.core.config import settings


async def enqueue_slice(slicing_job_id: UUID) -> None:
    pool = await create_pool(RedisSettings.from_dsn(settings.REDIS_URL))
    try:
        await pool.enqueue_job("slice_task", str(slicing_job_id))
    finally:
        await pool.close()


def enqueue_slice_sync(slicing_job_id: UUID) -> None:
    """Sync wrapper for use inside threadpool-executed FastAPI routes."""
    asyncio.run(enqueue_slice(slicing_job_id))
