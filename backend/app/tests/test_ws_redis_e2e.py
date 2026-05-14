"""Real-Redis pub/sub end-to-end test (PRD §9.1).

Auto-skips when no Redis is reachable. Run via:
    docker-compose up -d redis
    pytest app/tests/test_ws_redis_e2e.py -v
"""

from __future__ import annotations

import asyncio
import json
import uuid

import pytest

from app.core.config import settings


pytestmark = pytest.mark.asyncio


async def _redis_reachable() -> bool:
    try:
        import redis.asyncio as aioredis

        client = aioredis.from_url(settings.REDIS_URL, decode_responses=True)
        try:
            await client.ping()
            return True
        finally:
            await client.close()
    except Exception:
        return False


async def test_publish_async_round_trip():
    if not await _redis_reachable():
        pytest.skip(f"redis not reachable at {settings.REDIS_URL}")

    import redis.asyncio as aioredis

    from app.ws import events as ws_events

    topic = f"job:{uuid.uuid4()}"
    channel = f"{ws_events.CHANNEL_PREFIX}{topic}"

    sub = aioredis.from_url(settings.REDIS_URL, decode_responses=True)
    pubsub = sub.pubsub()
    await pubsub.subscribe(channel)

    # Drain the initial subscribe-confirm message
    await pubsub.get_message(timeout=1.0)

    await ws_events.publish_async(topic, "job.status", {"id": "x", "status": "queued"})

    received = None
    for _ in range(20):  # up to ~2s
        msg = await pubsub.get_message(timeout=0.1)
        if msg and msg.get("type") == "message":
            received = msg
            break
        await asyncio.sleep(0.05)

    try:
        assert received is not None, "no message received from Redis pub/sub"
        envelope = json.loads(received["data"])
        assert envelope["op"] == "event"
        assert envelope["topic"] == topic
        assert envelope["type"] == "job.status"
        assert envelope["data"]["status"] == "queued"
    finally:
        await pubsub.unsubscribe(channel)
        await pubsub.close()
        await sub.close()
        await ws_events.stop_subscriber()


async def test_last_event_cache_populated():
    if not await _redis_reachable():
        pytest.skip(f"redis not reachable at {settings.REDIS_URL}")

    from app.ws import events as ws_events

    topic = f"stl:{uuid.uuid4()}"
    await ws_events.publish_async(topic, "stl.status", {"id": "x", "status": "ready"})

    last = await ws_events.get_last_event(topic)
    assert last is not None
    assert last["topic"] == topic
    assert last["data"]["status"] == "ready"

    await ws_events.stop_subscriber()
