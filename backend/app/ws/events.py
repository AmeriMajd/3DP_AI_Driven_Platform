"""Event publish helper + Redis pub/sub subscriber.

Public surface:
- `publish(topic, type, data)`         — call from sync code (uses asyncio.run_coroutine_threadsafe path? No — we expose async)
- `async publish_async(topic, type, data)` — async version, used from FastAPI routes/services
- `get_last_event(topic)`              — async, returns cached payload or None
- `start_subscriber(loop)`             — async, runs forever; fans Redis messages into the local ConnectionManager
- `stop_subscriber()`                  — async, graceful shutdown

Channels mirror topics 1:1 with a `ws:` prefix (e.g. `ws:job:42`).
Last-event cache: key `ws:last:{topic}`, TTL = settings.WS_LAST_EVENT_TTL_S, refreshed on publish.
"""

from __future__ import annotations

import asyncio
import json
import logging
from datetime import datetime, timezone
from typing import Any, Optional

import redis.asyncio as aioredis

from app.core.config import settings
from app.ws.manager import manager
from app.ws.protocol import EventOp

logger = logging.getLogger(__name__)

CHANNEL_PREFIX = "ws:"
LAST_PREFIX = "ws:last:"
PATTERN = f"{CHANNEL_PREFIX}*"

_pub_client: Optional[aioredis.Redis] = None
_sub_client: Optional[aioredis.Redis] = None
_sub_task: Optional[asyncio.Task] = None


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


async def _get_pub() -> aioredis.Redis:
    global _pub_client
    if _pub_client is None:
        _pub_client = aioredis.from_url(settings.REDIS_URL, decode_responses=True)
    return _pub_client


def _build_envelope(topic: str, type_: str, data: dict[str, Any]) -> dict[str, Any]:
    return EventOp(topic=topic, type=type_, timestamp=_now_iso(), data=data).model_dump()


async def publish_async(topic: str, type_: str, data: dict[str, Any]) -> None:
    """Publish event to Redis + refresh last-event cache. Best-effort."""
    if not settings.WEBSOCKETS_ENABLED:
        return
    envelope = _build_envelope(topic, type_, data)
    payload = json.dumps(envelope)
    try:
        client = await _get_pub()
        pipe = client.pipeline()
        pipe.publish(f"{CHANNEL_PREFIX}{topic}", payload)
        pipe.set(f"{LAST_PREFIX}{topic}", payload, ex=settings.WS_LAST_EVENT_TTL_S)
        await pipe.execute()
    except Exception:
        logger.warning("ws publish failed (topic=%s type=%s)", topic, type_, exc_info=True)


async def _publish_with_fresh_client(
    topic: str, type_: str, data: dict[str, Any]
) -> None:
    """Variant of `publish_async` that creates and tears down its own Redis
    connection. Used from the sync `publish()` path where `asyncio.run` closes
    the loop on exit — caching a connection across calls would bind the new
    loop's resources to a dead loop and raise 'Event loop is closed'.
    """
    if not settings.WEBSOCKETS_ENABLED:
        return
    envelope = _build_envelope(topic, type_, data)
    payload = json.dumps(envelope)
    client = aioredis.from_url(settings.REDIS_URL, decode_responses=True)
    try:
        pipe = client.pipeline()
        pipe.publish(f"{CHANNEL_PREFIX}{topic}", payload)
        pipe.set(f"{LAST_PREFIX}{topic}", payload, ex=settings.WS_LAST_EVENT_TTL_S)
        await pipe.execute()
    except Exception:
        logger.warning("ws publish failed (topic=%s type=%s)", topic, type_, exc_info=True)
    finally:
        try:
            await client.aclose()
        except Exception:
            pass


def publish(topic: str, type_: str, data: dict[str, Any]) -> None:
    """Sync entrypoint for callers outside an event loop (worker, BackgroundTasks).

    Best-effort: never raises. If a loop is already running in this thread,
    schedules the coroutine on it (reusing the cached pool via `publish_async`).
    Otherwise spins up a fresh loop AND a fresh Redis client per call, so a
    closed loop never references a stale connection.
    """
    if not settings.WEBSOCKETS_ENABLED:
        return
    try:
        try:
            loop = asyncio.get_running_loop()
        except RuntimeError:
            asyncio.run(_publish_with_fresh_client(topic, type_, data))
            return
        loop.create_task(publish_async(topic, type_, data))
    except Exception:
        logger.warning("ws publish dispatch failed (topic=%s type=%s)", topic, type_, exc_info=True)


async def get_last_event(topic: str) -> Optional[dict[str, Any]]:
    client = await _get_pub()
    raw = await client.get(f"{LAST_PREFIX}{topic}")
    if raw is None:
        return None
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return None


# ── Subscriber loop ──────────────────────────────────────────────────────────


async def _subscriber_loop() -> None:
    global _sub_client
    _sub_client = aioredis.from_url(settings.REDIS_URL, decode_responses=True)
    pubsub = _sub_client.pubsub()
    await pubsub.psubscribe(PATTERN)
    logger.info("ws subscriber listening on %s", PATTERN)
    try:
        async for msg in pubsub.listen():
            if msg.get("type") != "pmessage":
                continue
            channel: str = msg["channel"]
            if not channel.startswith(CHANNEL_PREFIX):
                continue
            topic = channel[len(CHANNEL_PREFIX):]
            try:
                payload = json.loads(msg["data"])
            except (json.JSONDecodeError, TypeError):
                continue
            await manager.broadcast(topic, payload)
    except asyncio.CancelledError:
        pass
    finally:
        try:
            await pubsub.punsubscribe(PATTERN)
            await pubsub.close()
        except Exception:
            pass


async def start_subscriber() -> None:
    global _sub_task
    if _sub_task is not None and not _sub_task.done():
        return
    if not settings.WEBSOCKETS_ENABLED:
        return
    _sub_task = asyncio.create_task(_subscriber_loop())


async def stop_subscriber() -> None:
    global _sub_task, _sub_client, _pub_client
    if _sub_task is not None:
        _sub_task.cancel()
        try:
            await _sub_task
        except (asyncio.CancelledError, Exception):
            pass
        _sub_task = None
    if _sub_client is not None:
        try:
            await _sub_client.close()
        except Exception:
            pass
        _sub_client = None
    if _pub_client is not None:
        try:
            await _pub_client.close()
        except Exception:
            pass
        _pub_client = None
