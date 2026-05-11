import uuid
from datetime import datetime, timezone

from sqlalchemy import (
    BigInteger,
    Column,
    DateTime,
    Enum,
    ForeignKey,
    String,
    Text,
)
from sqlalchemy.dialects.postgresql import UUID

from app.core.database import Base


class SlicingJob(Base):
    __tablename__ = "slicing_jobs"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    print_job_id = Column(
        UUID(as_uuid=True),
        ForeignKey("print_jobs.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
        index=True,
    )

    status = Column(
        Enum(
            "queued",
            "running",
            "done",
            "error",
            "canceled",
            name="slicing_job_status_enum",
        ),
        nullable=False,
        default="queued",
        index=True,
    )

    gcode_path = Column(Text, nullable=True)
    file_size_bytes = Column(BigInteger, nullable=True)
    error_message = Column(Text, nullable=True)
    worker_id = Column(String, nullable=True)

    started_at = Column(DateTime(timezone=True), nullable=True)
    ended_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )
