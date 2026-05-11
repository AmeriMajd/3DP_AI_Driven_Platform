import random
import uuid
from typing import TYPE_CHECKING

from app.connectors.base import (
    BaseConnector,
    JobResult,
    JobSubmission,
    PrinterState,
    PrinterStatus,
)

if TYPE_CHECKING:
    from app.models.printer import Printer

# Keyed by printer id (str) so each mock printer has independent state.
_state: dict[str, dict] = {}


def _get(printer_id: str) -> dict:
    if printer_id not in _state:
        _state[printer_id] = {
            "state": PrinterState.IDLE,
            "progress": None,
            "job_name": None,
            "nozzle_target": 210.0,
            "bed_target": 60.0,
        }
    return _state[printer_id]


class MockConnector(BaseConnector):
    def __init__(self, printer: "Printer") -> None:
        self._id = str(printer.id)

    async def test_connection(self) -> bool:
        return True

    async def get_status(self) -> PrinterStatus:
        s = _get(self._id)
        if s["state"] == PrinterState.PRINTING and s["progress"] is not None:
            s["progress"] = min(1.0, s["progress"] + 0.05)
            if s["progress"] >= 1.0:
                s["state"] = PrinterState.IDLE
                s["progress"] = None
                s["job_name"] = None

        nozzle_t = s["nozzle_target"]
        bed_t = s["bed_target"]
        return PrinterStatus(
            state=s["state"],
            nozzle_temp_actual=round(nozzle_t + random.uniform(-2, 2), 1),
            nozzle_temp_target=nozzle_t,
            bed_temp_actual=round(bed_t + random.uniform(-2, 2), 1),
            bed_temp_target=bed_t,
            progress=s["progress"],
            time_left_seconds=None,
            current_job_name=s["job_name"],
        )

    async def submit_job(self, job: JobSubmission) -> JobResult:
        s = _get(self._id)
        s["state"] = PrinterState.PRINTING
        s["progress"] = 0.0
        s["job_name"] = job.file_name
        remote_id = str(uuid.uuid4())
        return JobResult(success=True, remote_job_id=remote_id, message=None)

    async def cancel_job(self) -> bool:
        s = _get(self._id)
        s["state"] = PrinterState.IDLE
        s["progress"] = None
        s["job_name"] = None
        return True
