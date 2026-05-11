from datetime import datetime
from typing import Literal, Optional
from uuid import UUID

from pydantic import BaseModel

SlicingStatus = Literal["queued", "running", "done", "error", "canceled"]


class SlicingJobRead(BaseModel):
    id: UUID
    user_id: UUID
    print_job_id: UUID
    status: SlicingStatus
    gcode_path: Optional[str] = None
    file_size_bytes: Optional[int] = None
    error_message: Optional[str] = None
    worker_id: Optional[str] = None
    started_at: Optional[datetime] = None
    ended_at: Optional[datetime] = None
    created_at: datetime

    model_config = {"from_attributes": True}
