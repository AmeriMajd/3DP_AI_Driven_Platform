from sqlalchemy import text
import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, Integer, Float, DateTime, ForeignKey, Boolean
from sqlalchemy.dialects.postgresql import UUID
from app.core.database import Base


class STLFile(Base):
    __tablename__ = "stl_files"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    original_filename = Column(String, nullable=False)
    stored_filename = Column(String, nullable=False, unique=True)
    file_size_bytes = Column(Integer, nullable=False)

    # Populated by geometry extraction — all nullable at upload time
    volume_cm3 = Column(Float, nullable=True)
    surface_area_cm2 = Column(Float, nullable=True)
    bbox_x_mm = Column(Float, nullable=True)
    bbox_y_mm = Column(Float, nullable=True)
    bbox_z_mm = Column(Float, nullable=True)
    triangle_count = Column(Integer, nullable=True)
    has_overhangs = Column(Boolean, nullable=True)  # None=unknown, True=yes, False=no
    has_thin_walls = Column(Boolean, nullable=True)

    # Status progression: 'uploaded' → 'analyzing' → 'ready' | 'error'
    status = Column(String, nullable=False, default="uploaded")

    created_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )
    updated_at = Column(
    DateTime(timezone=True),
    nullable=False,
    default=lambda: datetime.now(timezone.utc),
    onupdate=lambda: datetime.now(timezone.utc),
    server_default=text("now()"),  # ✅ lets Postgres handle it if Python default misses
)