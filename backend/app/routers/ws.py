"""WebSocket router — single endpoint `/ws`.

Flow:
1. Accept handshake.
2. Validate `?token=` JWT; close 4401 if invalid.
3. Spawn writer task on the Connection.
4. Recv loop: parse op → handle subscribe/unsubscribe/ping.
5. Cleanup on disconnect.

Per-connection JWT expiry timer closes 4401 when token expires.
"""

from __future__ import annotations

import asyncio
import logging
import time
from typing import Any, Optional

from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect, status
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import SessionLocal
from app.ws import events
from app.ws.auth import WSAuthError, authorize_topic, verify_ws_token
from app.ws.manager import Connection, manager
from app.ws.protocol import (
    CLOSE_POLICY,
    CLOSE_UNAUTHORIZED,
    ERR_BAD_OP,
    ERR_FORBIDDEN,
    ERR_INVALID_TOPIC,
    ERR_TOPIC_LIMIT,
    ErrorOp,
    PongOp,
    SubscribedAck,
    UnsubscribedAck,
)

router = APIRouter(tags=["WebSocket"])
logger = logging.getLogger(__name__)


_VALID_TOPIC_PREFIXES = ("job:", "stl:", "printer:")
_VALID_TOPIC_EXACT = {"admin:jobs"}


def _is_well_formed(topic: str) -> bool:
    if topic in _VALID_TOPIC_EXACT:
        return True
    return any(topic.startswith(p) for p in _VALID_TOPIC_PREFIXES)


@router.websocket("/ws")
async def ws_endpoint(
    websocket: WebSocket,
    token: str = Query(...),
) -> None:
    if not settings.WEBSOCKETS_ENABLED:
        await websocket.close(code=status.WS_1013_TRY_AGAIN_LATER)
        return

    # 1. Auth — open a short-lived DB session just for verify
    db: Session = SessionLocal()
    try:
        try:
            principal = verify_ws_token(token, db)
        except WSAuthError:
            await websocket.close(code=CLOSE_UNAUTHORIZED)
            return
    finally:
        db.close()

    # 2. Per-user socket cap
    if manager.sockets_for_user(principal.user_id) >= settings.WS_MAX_SOCKETS_PER_USER:
        await websocket.close(code=CLOSE_POLICY)
        return

    await websocket.accept()

    conn = Connection(
        websocket=websocket,
        user_id=principal.user_id,
        role=principal.role,
        token_exp_ts=principal.token_exp_ts,
        queue_max=settings.WS_SEND_QUEUE_MAX,
        backpressure_grace_s=settings.WS_BACKPRESSURE_GRACE_S,
    )
    conn.start_writer()
    await manager.add(conn)

    expiry_task = asyncio.create_task(_expiry_watchdog(conn))

    try:
        while True:
            try:
                raw = await websocket.receive_json()
            except WebSocketDisconnect:
                return
            except Exception:
                # Non-JSON frame — ignore
                continue
            await _handle_op(conn, raw)
    finally:
        expiry_task.cancel()
        await manager.remove(conn)
        await conn.aclose()


async def _handle_op(conn: Connection, raw: Any) -> None:
    if not isinstance(raw, dict):
        await conn.send(ErrorOp(code=ERR_BAD_OP, message="payload must be object").model_dump())
        return
    op = raw.get("op")
    if op == "ping":
        await conn.send(PongOp().model_dump())
        return
    if op == "subscribe":
        await _handle_subscribe(conn, raw.get("topic"))
        return
    if op == "unsubscribe":
        await _handle_unsubscribe(conn, raw.get("topic"))
        return
    await conn.send(ErrorOp(code=ERR_BAD_OP, message=f"unknown op: {op!r}").model_dump())


async def _handle_subscribe(conn: Connection, topic: Optional[str]) -> None:
    if not isinstance(topic, str) or not _is_well_formed(topic):
        await conn.send(ErrorOp(code=ERR_INVALID_TOPIC, topic=topic if isinstance(topic, str) else None).model_dump())
        return
    if len(conn.topics) >= settings.WS_MAX_TOPICS_PER_CONNECTION and topic not in conn.topics:
        await conn.send(ErrorOp(code=ERR_TOPIC_LIMIT, topic=topic).model_dump())
        return

    # Authorize against fresh DB session
    db = SessionLocal()
    try:
        from app.ws.auth import WSPrincipal

        principal = WSPrincipal(
            user_id=conn.user_id, role=conn.role, token_exp_ts=conn.token_exp_ts
        )
        allowed = authorize_topic(principal, topic, db)
    finally:
        db.close()

    if not allowed:
        await conn.send(ErrorOp(code=ERR_FORBIDDEN, topic=topic).model_dump())
        return

    await manager.subscribe(conn, topic)
    await conn.send(SubscribedAck(topic=topic).model_dump())

    # Replay last-event cache, if any
    last = await events.get_last_event(topic)
    if last is not None:
        await conn.send(last)


async def _handle_unsubscribe(conn: Connection, topic: Optional[str]) -> None:
    if not isinstance(topic, str):
        await conn.send(ErrorOp(code=ERR_INVALID_TOPIC).model_dump())
        return
    await manager.unsubscribe(conn, topic)
    await conn.send(UnsubscribedAck(topic=topic).model_dump())


async def _expiry_watchdog(conn: Connection) -> None:
    """Close socket with 4401 when JWT expires."""
    delay = max(conn.token_exp_ts - time.time(), 0)
    try:
        await asyncio.sleep(delay)
    except asyncio.CancelledError:
        return
    await conn.aclose(code=CLOSE_UNAUTHORIZED)
