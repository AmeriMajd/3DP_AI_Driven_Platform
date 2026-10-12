"""In-process WebSocket connection manager with bounded send queues.

Each `Connection` owns:
- a `WebSocket`
- a set of subscribed topics
- a bounded `asyncio.Queue` of outgoing JSON payloads
- a writer task that drains the queue to the socket

Backpressure policy (per PRD §FR-B6):
- queue full → drop oldest first
- if queue is full continuously for `backpressure_grace_s` → close 1011
"""

from __future__ import annotations

import asyncio
import logging
import time
from collections import defaultdict
from typing import Any, Iterable, Optional

from fastapi import WebSocket

logger = logging.getLogger(__name__)


class Connection:
    def __init__(
        self,
        websocket: WebSocket,
        user_id: str,
        role: str,
        token_exp_ts: float,
        *,
        queue_max: int,
        backpressure_grace_s: float,
    ) -> None:
        self.ws = websocket
        self.user_id = user_id
        self.role = role
        self.token_exp_ts = token_exp_ts
        self.topics: set[str] = set()
        self._queue: asyncio.Queue[dict[str, Any]] = asyncio.Queue(maxsize=queue_max)
        self._backpressure_grace_s = backpressure_grace_s
        self._queue_full_since: Optional[float] = None
        self._writer_task: Optional[asyncio.Task] = None
        self._closed = False

    async def send(self, payload: dict[str, Any]) -> None:
        """Enqueue a payload; drop oldest on overflow."""
        if self._closed:
            return
        try:
            self._queue.put_nowait(payload)
            self._queue_full_since = None
        except asyncio.QueueFull:
            # Drop oldest, then enqueue new
            try:
                self._queue.get_nowait()
            except asyncio.QueueEmpty:
                pass
            try:
                self._queue.put_nowait(payload)
            except asyncio.QueueFull:
                pass
            now = time.monotonic()
            if self._queue_full_since is None:
                self._queue_full_since = now
            elif now - self._queue_full_since > self._backpressure_grace_s:
                logger.warning(
                    "ws backpressure grace exceeded; closing user=%s", self.user_id
                )
                await self._force_close(code=1011)

    async def _writer_loop(self) -> None:
        try:
            while not self._closed:
                payload = await self._queue.get()
                try:
                    await self.ws.send_json(payload)
                except Exception:
                    self._closed = True
                    return
        except asyncio.CancelledError:
            pass

    def start_writer(self) -> None:
        self._writer_task = asyncio.create_task(self._writer_loop())

    async def _force_close(self, code: int) -> None:
        self._closed = True
        try:
            await self.ws.close(code=code)
        except Exception:
            pass

    async def aclose(self, code: int = 1000) -> None:
        self._closed = True
        if self._writer_task is not None:
            self._writer_task.cancel()
        try:
            await self.ws.close(code=code)
        except Exception:
            pass


class ConnectionManager:
    """Maps topic → connections and user → connections.

    Thread/async-safety: a single asyncio lock guards mutations.
    """

    def __init__(self) -> None:
        self._topics: dict[str, set[Connection]] = defaultdict(set)
        self._by_user: dict[str, set[Connection]] = defaultdict(set)
        self._lock = asyncio.Lock()

    async def add(self, conn: Connection) -> None:
        async with self._lock:
            self._by_user[conn.user_id].add(conn)

    async def remove(self, conn: Connection) -> None:
        async with self._lock:
            for t in list(conn.topics):
                self._topics.get(t, set()).discard(conn)
                if not self._topics.get(t):
                    self._topics.pop(t, None)
            conn.topics.clear()
            self._by_user.get(conn.user_id, set()).discard(conn)
            if not self._by_user.get(conn.user_id):
                self._by_user.pop(conn.user_id, None)

    async def subscribe(self, conn: Connection, topic: str) -> None:
        async with self._lock:
            self._topics[topic].add(conn)
            conn.topics.add(topic)

    async def unsubscribe(self, conn: Connection, topic: str) -> None:
        async with self._lock:
            self._topics.get(topic, set()).discard(conn)
            if not self._topics.get(topic):
                self._topics.pop(topic, None)
            conn.topics.discard(topic)

    def sockets_for_user(self, user_id: str) -> int:
        return len(self._by_user.get(user_id, set()))

    async def broadcast(self, topic: str, payload: dict[str, Any]) -> None:
        async with self._lock:
            conns: Iterable[Connection] = list(self._topics.get(topic, set()))
        for c in conns:
            await c.send(payload)


# Singleton — imported by router and Redis subscriber
manager = ConnectionManager()
