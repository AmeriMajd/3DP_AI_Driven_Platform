from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from uuid import UUID


class STLFileResponse(BaseModel):
    id: UUID
    original_filename: str
    file_size_bytes: int
    status: str
    created_at: datetime
    updated_at: datetime

    # Geometric features: null until processed
    volume_cm3: Optional[float] = None
    surface_area_cm2: Optional[float] = None
    bbox_x_mm: Optional[float] = None
    bbox_y_mm: Optional[float] = None
    bbox_z_mm: Optional[float] = None
    triangle_count: Optional[int] = None
    has_overhangs: Optional[bool] = None
    has_thin_walls: Optional[bool] = None

    model_config = {"from_attributes": True}


class STLListResponse(BaseModel):
    total: int
    files: List[STLFileResponse]


class STLStatusUpdate(BaseModel):
    status: str