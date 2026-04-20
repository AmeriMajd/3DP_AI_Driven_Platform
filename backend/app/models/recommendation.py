import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, Integer, Float, DateTime, ForeignKey, Boolean, JSON
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy import text
from app.core.database import Base


class Recommendation(Base):
    __tablename__ = "recommendations"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    stl_file_id = Column(
        UUID(as_uuid=True),
        ForeignKey("stl_files.id", ondelete="CASCADE"),
        nullable=False,
    )

    # ── User intent inputs ────────────────────────────────────────────────────
    orientation_rank = Column(Integer, nullable=True)
    intended_use = Column(String, nullable=False)          # functional/decorative/prototype
    surface_finish = Column(String, nullable=False)        # rough/standard/fine
    needs_flexibility = Column(Boolean, nullable=False)
    strength_required = Column(String, nullable=False)     # low/medium/high
    budget_priority = Column(String, nullable=False)       # cost/quality/speed
    outdoor_use = Column(Boolean, nullable=False)

    # ── Recommendation result ─────────────────────────────────────────────────
    technology = Column(String, nullable=True)             # FDM/SLA
    material = Column(String, nullable=True)               # PLA/ABS/PETG/TPU/Resin-Std/Resin-Eng
    technology_confidence = Column(Float, nullable=True)
    material_confidence = Column(Float, nullable=True)
    confidence_tier = Column(String, nullable=True)        # high/medium/low

    layer_height = Column(Float, nullable=True)
    layer_height_min = Column(Float, nullable=True)
    layer_height_max = Column(Float, nullable=True)
    infill_density = Column(Integer, nullable=True)
    print_speed = Column(Integer, nullable=True)
    wall_count = Column(Integer, nullable=True)
    cooling_fan = Column(Integer, nullable=True)
    support_density = Column(Integer, nullable=True)

    cost_score = Column(Integer, nullable=True)
    quality_score = Column(Integer, nullable=True)
    speed_score = Column(Integer, nullable=True)

    needs_clarification = Column(Boolean, nullable=False, default=False)
    clarification_question = Column(String, nullable=True)
    clarification_field = Column(String, nullable=True)

    # Stored as JSONB blob — avoids extra table; deserialized in Pydantic schema
    alternative_json = Column(JSON, nullable=True)

    # Selected orientation details (rx/ry/rz/overhang_reduction_pct/print_height_mm)
    # extracted from stl_file.best_orientation_{rank} at recommendation creation time
    selected_orientation_json = Column(JSON, nullable=True)

    # ── User feedback ─────────────────────────────────────────────────────────
    user_rating = Column(Integer, nullable=True)           # 1–5

    # ── Timestamps ────────────────────────────────────────────────────────────
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
        server_default=text("now()"),
    )
