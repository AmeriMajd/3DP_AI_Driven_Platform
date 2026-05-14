from pydantic import BaseModel
from datetime import datetime
from uuid import UUID


class UserListItem(BaseModel):
    id: UUID
    full_name: str
    email: str
    role: str
    is_active: bool
    created_at: datetime
    jobs_count: int

    model_config = {"from_attributes": True}
