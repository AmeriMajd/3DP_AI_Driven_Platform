from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from uuid import UUID


class OrientationResult(BaseModel):
    rank: int
    rx_deg: float
    ry_deg: float
    rz_deg: float
    score: float
    overhang_reduction_pct: float
    print_height_mm: float
    support_volume_mm3: float
    contact_area_mm2: float
    build_height_mm: float


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

    # Sprint 2B — detailed geometry features
    overhang_ratio: Optional[float] = None
    max_overhang_angle: Optional[float] = None
    min_wall_thickness_mm: Optional[float] = None
    avg_wall_thickness_mm: Optional[float] = None
    complexity_index: Optional[float] = None
    aspect_ratio: Optional[float] = None
    is_watertight: Optional[bool] = None
    shell_count: Optional[int] = None
    com_offset_ratio: Optional[float] = None
    flat_base_area_mm2: Optional[float] = None
    face_normal_histogram: Optional[List[float]] = None

    glb_url: Optional[str] = None

    model_config = {"from_attributes": True}


class STLListResponse(BaseModel):
    total: int
    files: List[STLFileResponse]


class STLStatusUpdate(BaseModel):
    status: str
