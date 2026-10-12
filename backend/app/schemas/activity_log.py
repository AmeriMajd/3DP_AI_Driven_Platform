"""Activity log response schemas."""

from __future__ import annotations

from datetime import datetime
from typing import Any, Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class ActivityLogResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    timestamp: datetime
    actor_user_id: Optional[UUID] = None
    actor_name: Optional[str] = None
    event_type: str
    severity: str
    target_type: Optional[str] = None
    target_id: Optional[UUID] = None
    message: str
    metadata_json: Optional[dict[str, Any]] = None


class ActivityLogPage(BaseModel):
    items: list[ActivityLogResponse]
    total: int
    limit: int
    offset: int
