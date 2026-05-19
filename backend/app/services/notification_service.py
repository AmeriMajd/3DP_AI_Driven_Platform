"""Notification service — single entrypoint for emitting notifications.

Responsibilities:
- Persist a notification row in the DB.
- Best-effort dedupe via `collapse_key` within a short window so a burst
  of identical events (e.g. rapid progress ticks) doesn't fan out a stream
  of identical rows.
- Per-trigger rate limiting via Redis (`rate_limit_key` + window) so
  noisy event sources (e.g. defect detection) can't spam the user.
- Publish a `notification.new` event to the owning user's WS channel.
- Best-effort FCM push delivery.

The public surface is intentionally small: `emit(...)`. Domain code wires
its own helpers on top (e.g. `emit_print_failed`) in Phase 5.
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone
from typing import Any, Iterable, Optional
from uuid import UUID

from sqlalchemy import and_, func, select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.notification import Notification
from app.services import fcm_service, rate_limit
from app.ws.emit import emit_notification

logger = logging.getLogger(__name__)

# Window during which a duplicate (same user + collapse_key) is suppressed.
_DEDUPE_WINDOW_SECONDS = 5


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _is_duplicate(
    db: Session,
    *,
    user_id: UUID,
    collapse_key: str,
    window_seconds: int,
) -> bool:
    """True if a row with the same (user_id, collapse_key) was created within
    the dedupe window. Skipped entirely when collapse_key is empty.
    """
    cutoff = _utcnow() - timedelta(seconds=window_seconds)
    stmt = select(Notification.id).where(
        and_(
            Notification.user_id == user_id,
            Notification.collapse_key == collapse_key,
            Notification.created_at >= cutoff,
        )
    ).limit(1)
    return db.execute(stmt).first() is not None


def emit(
    db: Session,
    *,
    user_id: UUID,
    category: str,
    type_: str,
    title: str,
    body: Optional[str] = None,
    severity: str = "info",
    data: Optional[dict[str, Any]] = None,
    collapse_key: Optional[str] = None,
    dedupe_window_seconds: int = _DEDUPE_WINDOW_SECONDS,
    rate_limit_key: Optional[str] = None,
    rate_limit_seconds: int = 0,
) -> Optional[Notification]:
    """Persist + publish a notification.

    Returns the created `Notification`, or `None` if dropped by dedupe /
    rate limit.

    Anti-spam ordering (cheap → expensive):
    1. Rate-limit gate (Redis SET NX EX, single round-trip, no DB hit).
    2. Collapse-key dedupe (DB query within a short window).
    3. Persist + WS publish + FCM push.

    The caller owns the transaction — this function calls `db.flush()` to
    obtain an id but does NOT commit. That matches the rest of this codebase
    (see job_service, slicing_service).
    """
    # ── 1. Rate limit ────────────────────────────────────────────────────────
    if rate_limit_key and rate_limit_seconds > 0:
        if not rate_limit.acquire(rate_limit_key, rate_limit_seconds):
            logger.debug(
                "notification dropped by rate-limit (key=%s window=%ss)",
                rate_limit_key,
                rate_limit_seconds,
            )
            return None

    # ── 2. Collapse-key dedupe ───────────────────────────────────────────────
    if collapse_key and _is_duplicate(
        db,
        user_id=user_id,
        collapse_key=collapse_key,
        window_seconds=dedupe_window_seconds,
    ):
        logger.debug(
            "notification dropped by dedupe (user=%s collapse_key=%s)",
            user_id,
            collapse_key,
        )
        return None

    channels: list[str] = ["in_app"]

    row = Notification(
        user_id=user_id,
        category=category,
        type=type_,
        severity=severity,
        title=title,
        body=body,
        data=data,
        collapse_key=collapse_key,
        delivered_channels=channels,
    )
    db.add(row)
    db.flush()  # populate row.id + row.created_at for the WS payload

    try:
        emit_notification(
            user_id,
            notification_id=row.id,
            category=row.category,
            type_=row.type,
            severity=row.severity,
            title=row.title,
            body=row.body,
            data=row.data,
            collapse_key=row.collapse_key,
            created_at=row.created_at.isoformat() if row.created_at else None,
        )
    except Exception:
        # WS is best-effort — never block persistence.
        logger.warning("ws emit failed for notification %s", row.id, exc_info=True)

    # ── FCM push (best-effort) ────────────────────────────────────────────────
    if settings.FCM_ENABLED:
        # Inject category + type into the payload so the mobile client can
        # route the tap to the right screen without re-fetching.
        fcm_data: dict[str, Any] = dict(data or {})
        fcm_data.setdefault("notification_id", str(row.id))
        fcm_data.setdefault("category", category)
        fcm_data.setdefault("type", type_)
        try:
            sent = fcm_service.send_to_user(
                db,
                user_id=user_id,
                title=title,
                body=body,
                data=fcm_data,
                collapse_key=collapse_key,
                severity=severity,
            )
            if sent > 0:
                channels.append("fcm")
                row.delivered_channels = channels
                db.flush()
        except Exception:
            logger.warning(
                "fcm push failed for notification %s", row.id, exc_info=True
            )

    return row


# ── Read helpers ──────────────────────────────────────────────────────────────


def list_for_user(
    db: Session,
    *,
    user_id: UUID,
    category: Optional[str] = None,
    severities: Optional[Iterable[str]] = None,
    unread_only: bool = False,
    before: Optional[datetime] = None,
    limit: int = 30,
) -> list[Notification]:
    """Paginated read. Cursor is the `created_at` of the oldest row already
    returned — pass it as `before` for the next page.
    """
    stmt = select(Notification).where(Notification.user_id == user_id)
    if category is not None:
        stmt = stmt.where(Notification.category == category)
    if severities:
        stmt = stmt.where(Notification.severity.in_(list(severities)))
    if unread_only:
        stmt = stmt.where(Notification.read_at.is_(None))
    if before is not None:
        stmt = stmt.where(Notification.created_at < before)
    stmt = stmt.order_by(Notification.created_at.desc()).limit(limit)
    return list(db.execute(stmt).scalars().all())


def unread_count(db: Session, *, user_id: UUID) -> int:
    stmt = select(func.count(Notification.id)).where(
        and_(
            Notification.user_id == user_id,
            Notification.read_at.is_(None),
        )
    )
    return int(db.execute(stmt).scalar_one())


def mark_read(db: Session, *, user_id: UUID, notification_id: UUID) -> bool:
    """Mark a single notification read. Returns True on hit, False if the
    notification doesn't exist or doesn't belong to the user.
    """
    row = db.get(Notification, notification_id)
    if row is None or row.user_id != user_id:
        return False
    if row.read_at is None:
        row.read_at = _utcnow()
        db.flush()
    return True


def mark_all_read(db: Session, *, user_id: UUID) -> int:
    """Bulk mark-all. Returns affected row count."""
    now = _utcnow()
    result = (
        db.query(Notification)
        .filter(Notification.user_id == user_id, Notification.read_at.is_(None))
        .update({Notification.read_at: now}, synchronize_session=False)
    )
    db.flush()
    return int(result or 0)
