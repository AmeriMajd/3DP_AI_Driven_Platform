from typing import TYPE_CHECKING

import httpx

from app.connectors.base import (
    BaseConnector,
    JobResult,
    JobSubmission,
    PrinterState,
    PrinterStatus,
)

if TYPE_CHECKING:
    from app.models.printer import Printer

_TIMEOUT = 5.0

_OFFLINE_STATUS = PrinterStatus(
    state=PrinterState.OFFLINE,
    nozzle_temp_actual=None,
    nozzle_temp_target=None,
    bed_temp_actual=None,
    bed_temp_target=None,
    progress=None,
    time_left_seconds=None,
    current_job_name=None,
)


class PrusaLinkConnector(BaseConnector):
    def __init__(self, printer: "Printer") -> None:
        self._base = (printer.connection_url or "").rstrip("/")
        self._auth = httpx.DigestAuth(
            username=printer.username or "",
            password=printer.api_key or "",
        )

    def _client(self) -> httpx.AsyncClient:
        return httpx.AsyncClient(
            base_url=self._base, auth=self._auth, timeout=_TIMEOUT
        )

    async def test_connection(self) -> bool:
        try:
            async with self._client() as client:
                r = await client.get("/api/version")
                return r.status_code == 200
        except (httpx.TimeoutException, httpx.ConnectError):
            return False

    async def get_status(self) -> PrinterStatus:
        try:
            async with self._client() as client:
                import asyncio
                printer_r, job_r = await asyncio.gather(
                    client.get("/api/printer"),
                    client.get("/api/job"),
                )
        except (httpx.TimeoutException, httpx.ConnectError):
            return _OFFLINE_STATUS

        if printer_r.status_code != 200:
            return _OFFLINE_STATUS

        printer_data = printer_r.json()
        temps = printer_data.get("temperature", {})
        tool = temps.get("tool0", {})
        bed = temps.get("bed", {})

        # PrusaLink state text matches OctoPrint convention
        raw_state = printer_data.get("state", {}).get("text", "")
        state_map = {
            "Operational": PrinterState.IDLE,
            "Printing": PrinterState.PRINTING,
            "Paused": PrinterState.PAUSED,
            "Error": PrinterState.ERROR,
            "Offline": PrinterState.OFFLINE,
            "Closed": PrinterState.OFFLINE,
        }
        state = state_map.get(raw_state, PrinterState.UNKNOWN)

        progress = None
        time_left = None
        job_name = None
        if job_r.status_code == 200:
            job_data = job_r.json()
            prog = job_data.get("progress", {})
            completion = prog.get("completion")
            if completion is not None:
                progress = round(completion / 100.0, 4)
            time_left = prog.get("printTimeLeft")
            job_name = job_data.get("job", {}).get("file", {}).get("name")

        return PrinterStatus(
            state=state,
            nozzle_temp_actual=tool.get("actual"),
            nozzle_temp_target=tool.get("target"),
            bed_temp_actual=bed.get("actual"),
            bed_temp_target=bed.get("target"),
            progress=progress,
            time_left_seconds=time_left,
            current_job_name=job_name,
        )

    async def submit_job(self, job: JobSubmission) -> JobResult:
        try:
            async with self._client() as client:
                with open(job.file_path, "rb") as f:
                    r = await client.put(
                        f"/api/files/sdcard/{job.file_name}",
                        content=f.read(),
                        headers={"Content-Type": "application/octet-stream"},
                    )
                if r.status_code not in (200, 201, 204):
                    return JobResult(success=False, remote_job_id=None, message=r.text)
                if job.start_immediately:
                    await client.post("/api/job", json={"command": "start"})
                return JobResult(success=True, remote_job_id=None, message=None)
        except (httpx.TimeoutException, httpx.ConnectError) as e:
            return JobResult(success=False, remote_job_id=None, message=str(e))

    async def cancel_job(self) -> bool:
        try:
            async with self._client() as client:
                r = await client.delete("/api/job")
                return r.status_code in (200, 204)
        except (httpx.TimeoutException, httpx.ConnectError):
            return False
