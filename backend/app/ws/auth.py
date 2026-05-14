"""WebSocket auth: JWT verification from query string + per-topic authorization.

Topic grammar:
- `job:{uuid}`     — owner of PrintJob OR admin
- `stl:{uuid}`     — owner of STLFile OR admin
- `printer:{uuid}` — any authenticated user (shared fleet)
- `admin:jobs`     — admin only
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from typing import Optional

from jose import JWTError, jwt
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import ALGORITHM
from app.models.print_job import PrintJob
from app.models.stl_file import STLFile
from app.models.user import User


@dataclass
class WSPrincipal:
    user_id: str
    role: str
    token_exp_ts: float  # unix epoch seconds


class WSAuthError(Exception):
    pass


def verify_ws_token(token: str, db: Session) -> WSPrincipal:
    """Decode JWT and load active user. Raises WSAuthError on any failure."""
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[ALGORITHM])
    except JWTError as e:
        raise WSAuthError(f"invalid_token: {e}")

    sub = payload.get("sub")
    exp = payload.get("exp")
    if sub is None or exp is None:
        raise WSAuthError("missing_claims")

    try:
        user_uuid = uuid.UUID(str(sub))
    except ValueError:
        raise WSAuthError("bad_sub")

    user = db.query(User).filter(User.id == user_uuid).first()
    if user is None or user.is_active is False:
        raise WSAuthError("inactive_or_missing")

    return WSPrincipal(
        user_id=str(user.id), role=user.role, token_exp_ts=float(exp)
    )


# ── Topic authorization ──────────────────────────────────────────────────────


def _parse_uuid_suffix(topic: str, prefix: str) -> Optional[uuid.UUID]:
    if not topic.startswith(prefix):
        return None
    raw = topic[len(prefix):]
    try:
        return uuid.UUID(raw)
    except ValueError:
        return None


def authorize_topic(principal: WSPrincipal, topic: str, db: Session) -> bool:
    """Return True if the principal may subscribe to this topic.

    Never leaks existence — caller maps False to a generic `forbidden` error.
    """
    if topic == "admin:jobs":
        return principal.role == "admin"

    # job:{uuid}
    job_id = _parse_uuid_suffix(topic, "job:")
    if job_id is not None:
        if principal.role == "admin":
            return True
        row = (
            db.query(PrintJob.user_id)
            .filter(PrintJob.id == job_id)
            .first()
        )
        return row is not None and str(row.user_id) == principal.user_id

    # stl:{uuid}
    stl_id = _parse_uuid_suffix(topic, "stl:")
    if stl_id is not None:
        if principal.role == "admin":
            return True
        row = (
            db.query(STLFile.user_id)
            .filter(STLFile.id == stl_id)
            .first()
        )
        return row is not None and str(row.user_id) == principal.user_id

    # printer:{uuid} — any authenticated user (fleet is shared)
    printer_id = _parse_uuid_suffix(topic, "printer:")
    if printer_id is not None:
        return True

    return False
