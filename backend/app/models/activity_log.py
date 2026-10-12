"""ActivityLog model — admin-only platform audit trail.

Conventions:
- UUID PK, timezone-aware DateTime
- Native PG enum for event_type
- `metadata` column name — SQLAlchemy reserves `Model.metadata`, so the
  Python attribute is `metadata_json` mapping to DB column `metadata`.
"""

import enum
import uuid
from datetime import datetime, timezone

from sqlalchemy import (
    Column,
    DateTime,
    Enum,
    ForeignKey,
    JSON,
    String,
)
from sqlalchemy.dialects.postgresql import UUID

from app.core.database import Base


class ActivityEventType(str, enum.Enum):
    AUTH = "auth"
    JOB = "job"
    PRINTER = "printer"
    FILE = "file"
    NOTIFICATION = "notification"
    ANOMALY = "anomaly"
    ADMIN = "admin"


class ActivityLog(Base):
    __tablename__ = "activity_logs"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    timestamp = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
        index=True,
    )
    actor_user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    event_type = Column(
        Enum(
            "auth",
            "job",
            "printer",
            "file",
            "notification",
            "anomaly",
            "admin",
            name="activity_event_type_enum",
        ),
        nullable=False,
        index=True,
    )
    severity = Column(String(16), nullable=False, default="info")
    target_type = Column(String(32), nullable=True)
    target_id = Column(UUID(as_uuid=True), nullable=True)
    message = Column(String(512), nullable=False)
    metadata_json = Column("metadata", JSON, nullable=True)
