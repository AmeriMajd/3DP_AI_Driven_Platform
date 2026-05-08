from abc import ABC, abstractmethod
from dataclasses import dataclass
from enum import Enum
from typing import Optional


class PrinterState(str, Enum):
    IDLE = "idle"
    PRINTING = "printing"
    PAUSED = "paused"
    ERROR = "error"
    OFFLINE = "offline"
    UNKNOWN = "unknown"


@dataclass
class PrinterStatus:
    state: PrinterState
    nozzle_temp_actual: Optional[float]
    nozzle_temp_target: Optional[float]
    bed_temp_actual: Optional[float]
    bed_temp_target: Optional[float]
    progress: Optional[float]          # 0.0–1.0, None if not printing
    time_left_seconds: Optional[int]
    current_job_name: Optional[str]


@dataclass
class JobSubmission:
    file_path: str
    file_name: str
    start_immediately: bool = True


@dataclass
class JobResult:
    success: bool
    remote_job_id: Optional[str]
    message: Optional[str]


class BaseConnector(ABC):
    @abstractmethod
    async def test_connection(self) -> bool: ...

    @abstractmethod
    async def get_status(self) -> PrinterStatus: ...

    @abstractmethod
    async def submit_job(self, job: JobSubmission) -> JobResult: ...

    @abstractmethod
    async def cancel_job(self) -> bool: ...
