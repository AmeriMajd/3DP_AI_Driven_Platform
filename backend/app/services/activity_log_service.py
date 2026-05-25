"""Activity log service — best-effort persistence + filtered queries.

`log()` is wrapped in try/except and never raises into the caller — audit
failures must not break business operations. `query()` powers the admin
endpoint.
"""

from __future__ import annotations

import logging
from datetime import datetime
from typing import Any, Optional
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.activity_log import ActivityLog

logger = logging.getLogger(__name__)


def log(
    db: Session,
    *,
    event_type: str,
    message: str,
    actor_user_id: Optional[UUID] = None,
    severity: str = "info",
    target_type: Optional[str] = None,
    target_id: Optional[UUID] = None,
    metadata: Optional[dict[str, Any]] = None,
) -> Optional[ActivityLog]:
    """Persist one audit row. Never raises into caller.

    Uses a savepoint (nested transaction) so any DB error rolls back only
    the audit insert, leaving the caller's transaction intact.
    """
    try:
        row = ActivityLog(
            event_type=event_type,
            message=message[:512],
            actor_user_id=actor_user_id,
            severity=severity,
            target_type=target_type,
            target_id=target_id,
            metadata_json=metadata,
        )
        with db.begin_nested():
            db.add(row)
        return row
    except Exception:
        logger.warning(
            "activity_log: failed to persist event_type=%s message=%s",
            event_type,
            message,
            exc_info=True,
        )
        return None


def query(
    db: Session,
    *,
    date_from: Optional[datetime] = None,
    date_to: Optional[datetime] = None,
    event_type: Optional[str] = None,
    severity: Optional[str] = None,
    actor_user_id: Optional[UUID] = None,
    target_type: Optional[str] = None,
    limit: int = 50,
    offset: int = 0,
) -> tuple[list[ActivityLog], int]:
    """Filtered + paginated read. Returns (page_rows, total_count)."""
    stmt = select(ActivityLog)
    count_stmt = select(func.count(ActivityLog.id))

    filters = []
    if date_from is not None:
        filters.append(ActivityLog.timestamp >= date_from)
    if date_to is not None:
        filters.append(ActivityLog.timestamp <= date_to)
    if event_type is not None:
        filters.append(ActivityLog.event_type == event_type)
    if severity is not None:
        filters.append(ActivityLog.severity == severity)
    if actor_user_id is not None:
        filters.append(ActivityLog.actor_user_id == actor_user_id)
    if target_type is not None:
        filters.append(ActivityLog.target_type == target_type)

    for f in filters:
        stmt = stmt.where(f)
        count_stmt = count_stmt.where(f)

    total = int(db.execute(count_stmt).scalar_one() or 0)
    stmt = (
        stmt.order_by(ActivityLog.timestamp.desc())
        .limit(max(1, min(limit, 200)))
        .offset(max(0, offset))
    )
    rows = list(db.execute(stmt).scalars().all())
    return rows, total
