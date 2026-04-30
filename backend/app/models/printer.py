"""
Printer model — represents a 3D printer in the fleet.

Conventions followed (from existing models):
- UUID PK with as_uuid=True, default=uuid.uuid4
- created_at via lambda: datetime.now(timezone.utc)
- No relationship() declared — just plain ForeignKey on the child side
- JSON column for materials_supported (plain JSON, no JSONB override)
- Enum columns via SQLAlchemy.Enum with explicit `name=...`, matching the
  `role = Column(Enum("admin", "operator", name="user_role_enum"), ...)`
  pattern on User.
"""

import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, Enum, Float, JSON, LargeBinary, String
from sqlalchemy.dialects.postgresql import UUID

from app.core.database import Base


class Printer(Base):
    __tablename__ = "printers"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    name = Column(String, nullable=False)
    model = Column(String, nullable=True)

    technology = Column(
        Enum("FDM", "SLA", name="printer_technology_enum"),
        nullable=False,
    )

    build_volume_x = Column(Float, nullable=True)
    build_volume_y = Column(Float, nullable=True)
    build_volume_z = Column(Float, nullable=True)

    connector_type = Column(
        Enum("octoprint", "prusalink", "mock", "manual", name="printer_connector_enum"),
        nullable=False,
        default="mock",
    )
    connection_url = Column(String, nullable=True)

    # Encrypted via Fernet — never exposed in any response schema
    api_key_encrypted = Column(LargeBinary, nullable=True)

    status = Column(
        Enum(
            "idle", "printing", "error", "offline", "maintenance",
            name="printer_status_enum",
        ),
        nullable=False,
        default="offline",
    )

    # JSON array of material strings, e.g. ["PLA", "PETG", "ABS"]
    materials_supported = Column(JSON, nullable=True)

    last_seen_at = Column(DateTime(timezone=True), nullable=True)

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
    )