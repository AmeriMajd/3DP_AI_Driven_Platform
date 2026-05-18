"""Pydantic v2 schemas for the notifications API."""

from datetime import datetime
from typing import Any, Literal, Optional
from uuid import UUID

from pydantic import BaseModel, Field


NotificationCategory = Literal[
    "print_job",
    "ml_pipeline",
    "printer_health",
    "account_security",
]

NotificationSeverity = Literal["info", "success", "warning", "error"]

DevicePlatform = Literal["android", "ios", "web"]


# ---------- Read ----------


class NotificationRead(BaseModel):
    id: UUID
    user_id: UUID
    category: NotificationCategory
    type: str
    severity: NotificationSeverity
    title: str
    body: Optional[str] = None
    data: Optional[dict[str, Any]] = None
    collapse_key: Optional[str] = None
    delivered_channels: list[str] = Field(default_factory=list)
    created_at: datetime
    read_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class NotificationListResponse(BaseModel):
    items: list[NotificationRead]
    next_cursor: Optional[str] = None
    unread_count: int


class UnreadCountResponse(BaseModel):
    unread_count: int


# ---------- Device registration ----------


class DeviceRegister(BaseModel):
    fcm_token: str = Field(min_length=1, max_length=512)
    platform: DevicePlatform
    device_label: Optional[str] = Field(default=None, max_length=128)
    app_version: Optional[str] = Field(default=None, max_length=32)


class DeviceRead(BaseModel):
    id: UUID
    user_id: UUID
    fcm_token: str
    platform: DevicePlatform
    device_label: Optional[str] = None
    app_version: Optional[str] = None
    created_at: datetime
    last_seen_at: datetime

    model_config = {"from_attributes": True}
