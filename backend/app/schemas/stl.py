from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from uuid import UUID

class STLFileResponse(BaseModel):
    id: UUID
    original_file_name: str
    file_size: int
    status: str
    created_at: datetime

    #geomitric features : null until the stl file is processed
    volume_cm3: Optional[float] = None
    surface_area_cm2: Optional[float] = None
    bbox_x_mm: Optional[float] = None
    bbox_y_mm: Optional[float] = None
    bbox_z_mm: Optional[float] = None
    triangle_count: Optional[int] = None
    has_overhangs: Optional[bool] = None
    has_thin_walls: Optional[bool] = None

    model_config={"from_attributes": True}

class STLListResponse(BaseModel):
    total: int
    stl_files: List[STLFileResponse]

