"""
Pydantic v2 schemas for PrintJob.

⚠️ JobRead must match the frozen API contract exactly — field names, nullability,
and enum values are load-bearing for Dev B's Flutter mocks. Do not change without
a sync.
"""

from datetime import datetime
from typing import Any, Literal, Optional
from uuid import UUID

from pydantic import BaseModel, Field

JobStatus = Literal[
    "queued",
    "scheduled",
    "printing",
    "completed",
    "failed",
    "canceled",
    "paused",
]


# ---------- Create ----------


class JobCreate(BaseModel):
    """Request body for POST /jobs.

    `recommendation_id` is REQUIRED in this sprint — the matcher needs
    technology + material to find a compatible printer.
    """

    stl_file_id: UUID
    recommendation_id: UUID
    priority: int = Field(default=3, ge=1, le=5)
    parameters_override: Optional[dict[str, Any]] = None


# ---------- Read (response model) ----------


class JobRead(BaseModel):
    """Public response shape — frozen contract."""

    id: UUID
    user_id: UUID
    stl_file_id: UUID
    recommendation_id: Optional[UUID] = None
    printer_id: Optional[UUID] = None

    status: JobStatus
    priority: int
    progress_pct: float

    estimated_duration_s: Optional[int] = None
    actual_duration_s: Optional[int] = None
    estimated_cost: Optional[float] = None

    submitted_at: datetime
    scheduled_at: Optional[datetime] = None
    started_at: Optional[datetime] = None
    ended_at: Optional[datetime] = None

    error_message: Optional[str] = None

    model_config = {"from_attributes": True}