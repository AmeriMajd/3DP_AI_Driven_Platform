"""
PrintJob model — represents a single print job submitted by a user.

Conventions followed:
- UUID PK with as_uuid=True, default=uuid.uuid4
- created_at via lambda: datetime.now(timezone.utc) (here named submitted_at)
- No relationship() declared — plain ForeignKey only
- Native PG enums via SQLAlchemy.Enum(..., name=...) matching user_role_enum style
- JSON column for parameters_override (plain JSON, no JSONB override)
"""

import uuid
from datetime import datetime, timezone

from sqlalchemy import (
    Column,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Integer,
    JSON,
    String,
    text,
)
from sqlalchemy.dialects.postgresql import UUID

from app.core.database import Base


class PrintJob(Base):
    __tablename__ = "print_jobs"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    stl_file_id = Column(
        UUID(as_uuid=True),
        ForeignKey("stl_files.id", ondelete="CASCADE"),
        nullable=False,
    )
    recommendation_id = Column(
        UUID(as_uuid=True),
        ForeignKey("recommendations.id", ondelete="SET NULL"),
        nullable=True,
    )
    printer_id = Column(
        UUID(as_uuid=True),
        ForeignKey("printers.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    status = Column(
        Enum(
            "queued",
            "scheduled",
            "printing",
            "completed",
            "failed",
            "canceled",
            "paused",
            name="print_job_status_enum",
        ),
        nullable=False,
        default="queued",
        index=True,
    )

    priority = Column(Integer, nullable=False, default=3)  # 1..5, higher = more urgent
    progress_pct = Column(Float, nullable=False, default=0.0)

    estimated_duration_s = Column(Integer, nullable=True)
    actual_duration_s = Column(Integer, nullable=True)
    estimated_cost = Column(Float, nullable=True)

    parameters_override = Column(JSON, nullable=True)

    submitted_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )
    scheduled_at = Column(DateTime(timezone=True), nullable=True)
    started_at = Column(DateTime(timezone=True), nullable=True)
    ended_at = Column(DateTime(timezone=True), nullable=True)

    error_message = Column(String, nullable=True)