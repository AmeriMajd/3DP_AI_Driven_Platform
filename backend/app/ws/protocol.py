"""WebSocket wire protocol — all client/server messages are JSON with an `op` field.

Envelope shapes documented in docs/PRD_WEBSOCKETS.md §5.6.
"""

from datetime import datetime, timezone
from typing import Any, Literal, Optional

from pydantic import BaseModel, Field


# ── Client → server ops ───────────────────────────────────────────────────────


class SubscribeOp(BaseModel):
    op: Literal["subscribe"]
    topic: str


class UnsubscribeOp(BaseModel):
    op: Literal["unsubscribe"]
    topic: str


class PingOp(BaseModel):
    op: Literal["ping"]


# ── Server → client ops ───────────────────────────────────────────────────────


class SubscribedAck(BaseModel):
    op: Literal["subscribed"] = "subscribed"
    topic: str


class UnsubscribedAck(BaseModel):
    op: Literal["unsubscribed"] = "unsubscribed"
    topic: str


class PongOp(BaseModel):
    op: Literal["pong"] = "pong"


class ErrorOp(BaseModel):
    op: Literal["error"] = "error"
    code: str
    topic: Optional[str] = None
    message: Optional[str] = None


class EventOp(BaseModel):
    op: Literal["event"] = "event"
    topic: str
    type: str
    timestamp: str = Field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )
    data: dict[str, Any] = Field(default_factory=dict)


# ── Error codes ───────────────────────────────────────────────────────────────

ERR_FORBIDDEN = "forbidden"
ERR_INVALID_TOPIC = "invalid_topic"
ERR_BAD_OP = "bad_op"
ERR_TOPIC_LIMIT = "topic_limit"

# ── Close codes ───────────────────────────────────────────────────────────────

CLOSE_UNAUTHORIZED = 4401
CLOSE_INTERNAL = 1011
CLOSE_POLICY = 1008
