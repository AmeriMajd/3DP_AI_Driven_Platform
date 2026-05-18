"""UserDevice model — stores FCM tokens per device for push delivery.

A single user may have multiple devices (phone + tablet). Tokens may
rotate (app reinstall, restore from backup), so we keep `fcm_token`
unique and overwrite existing rows on conflict at the service layer.
"""

import uuid
from datetime import datetime, timezone

from sqlalchemy import (
    Column,
    DateTime,
    Enum,
    ForeignKey,
    String,
)
from sqlalchemy.dialects.postgresql import UUID

from app.core.database import Base


class UserDevice(Base):
    __tablename__ = "user_devices"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    fcm_token = Column(String(512), nullable=False, unique=True, index=True)

    platform = Column(
        Enum(
            "android",
            "ios",
            "web",
            name="user_device_platform_enum",
        ),
        nullable=False,
    )

    # Optional human-friendly device label ("Majd's iPhone").
    device_label = Column(String(128), nullable=True)

    # App version at time of registration — useful for debugging push issues
    # tied to a specific client build.
    app_version = Column(String(32), nullable=True)

    created_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )
    last_seen_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )
