from datetime import datetime
from typing import Literal, Optional
from uuid import UUID

from pydantic import BaseModel

Range = Literal["7d", "30d", "90d", "all"]


class KpiItem(BaseModel):
    value: float
    delta_pct: float
    sub: str


class DashboardKpis(BaseModel):
    active_jobs: KpiItem
    revenue_today: KpiItem
    success_rate: KpiItem
    queue_depth: KpiItem


class RevenuePoint(BaseModel):
    date: str
    value: float


class JobsByStatusPoint(BaseModel):
    date: str
    completed: int
    failed: int
    canceled: int


class ActiveJobItem(BaseModel):
    id: UUID
    user_name: str
    printer_name: str
    file: Optional[str] = None
    status: str
    progress_pct: float
    estimated_cost: Optional[float] = None
    estimated_duration_s: Optional[int] = None
    time_left_seconds: Optional[int] = None
    submitted_at: datetime


class RecentJobItem(BaseModel):
    id: UUID
    user_name: str
    printer_name: Optional[str] = None
    status: str
    estimated_cost: Optional[float] = None
    duration_s: Optional[int] = None
    submitted_at: datetime


class TopUserItem(BaseModel):
    user_id: UUID
    full_name: str
    total_cost: float
    jobs_count: int
