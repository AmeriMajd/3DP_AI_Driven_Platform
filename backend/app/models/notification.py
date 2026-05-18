"""Notification model — persisted notification record for in-app history.

Conventions match other models in this package:
- UUID PK with as_uuid=True, default=uuid.uuid4
- timezone-aware DateTime via lambda: datetime.now(timezone.utc)
- No relationship() declared — plain ForeignKey only
- Native PG enum for category
- Plain JSON column for arbitrary payload (data)
"""

import uuid
from datetime import datetime, timezone

from sqlalchemy import (
    ARRAY,
    Column,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    JSON,
    String,
)
from sqlalchemy.dialects.postgresql import UUID

from app.core.database import Base


class Notification(Base):
    __tablename__ = "notifications"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # High-level grouping used by frontend filter chips.
    category = Column(
        Enum(
            "print_job",
            "ml_pipeline",
            "printer_health",
            "account_security",
            name="notification_category_enum",
        ),
        nullable=False,
        index=True,
    )

    # Fine-grained event type (e.g. "print.failed", "job.progress",
    # "printer.filament_low"). Free-form string to keep schema flexible
    # as new triggers come online.
    type = Column(String(64), nullable=False, index=True)

    # Severity hint for UI rendering / OS channel selection.
    severity = Column(
        Enum(
            "info",
            "success",
            "warning",
            "error",
            name="notification_severity_enum",
        ),
        nullable=False,
        default="info",
    )

    title = Column(String(255), nullable=False)
    body = Column(String(1024), nullable=True)

    # Arbitrary payload for deep linking and UI rendering. Examples:
    # {"job_id": "...", "printer_id": "..."}
    data = Column(JSON, nullable=True)

    # Collapse key for FCM tray replacement (e.g. "job_<id>_progress").
    # Also used for backend-side dedupe within a short window.
    collapse_key = Column(String(128), nullable=True, index=True)

    # Channels through which this notification was delivered.
    # Values: "in_app", "fcm". Populated by NotificationService.
    delivered_channels = Column(ARRAY(String), nullable=False, default=list)

    created_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        index=True,
    )
    read_at = Column(DateTime(timezone=True), nullable=True)


# Composite index to speed up the most common query:
# "unread notifications for a user, newest first".
Index(
    "ix_notifications_user_unread_created",
    Notification.user_id,
    Notification.read_at,
    Notification.created_at.desc(),
)
