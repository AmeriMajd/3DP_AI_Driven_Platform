"""
Unit tests for OctoPrintConnector.
HTTP calls stubbed via httpx.MockTransport — no real network needed.
"""

import uuid
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

import httpx
import pytest

from app.connectors.base import JobSubmission, PrinterState
from app.connectors.octoprint import OctoPrintConnector


def _printer(url="http://octo.local", api_key="test-key"):
    return SimpleNamespace(
        id=uuid.uuid4(),
        connector_type="octoprint",
        connection_url=url,
        api_key=api_key,
    )


def _resp(status_code: int, json_body: dict | None = None) -> httpx.Response:
    return httpx.Response(
        status_code=status_code,
        json=json_body or {},
        request=httpx.Request("GET", "http://octo.local"),
    )


_PRINTER_PRINTING = {
    "state": {"text": "Printing"},
    "temperature": {
        "tool0": {"actual": 210.5, "target": 210.0},
        "bed": {"actual": 60.2, "target": 60.0},
    },
}

_JOB_PRINTING = {
    "progress": {"completion": 42.0, "printTimeLeft": 1200},
    "job": {"file": {"name": "benchy.gcode"}},
}

_PRINTER_IDLE = {
    "state": {"text": "Operational"},
    "temperature": {
        "tool0": {"actual": 25.0, "target": 0.0},
        "bed": {"actual": 22.0, "target": 0.0},
    },
}

_JOB_IDLE = {"progress": {}, "job": {"file": {"name": None}}}


# ── helpers ───────────────────────────────────────────────────────────────────

def _patch_fetch(printer_resp, job_resp):
    return patch(
        "app.connectors.octoprint._fetch_both",
        new=AsyncMock(return_value=(printer_resp, job_resp)),
    )


def _patch_client(connector, client_mock):
    cm = AsyncMock()
    cm.__aenter__ = AsyncMock(return_value=client_mock)
    cm.__aexit__ = AsyncMock(return_value=False)
    return patch.object(connector, "_client", return_value=cm)


# ── test_connection ───────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_connection_ok():
    c = OctoPrintConnector(_printer())
    client_mock = AsyncMock(get=AsyncMock(return_value=_resp(200, {"api": "0.1.0"})))
    with _patch_client(c, client_mock):
        assert await c.test_connection() is True


@pytest.mark.asyncio
async def test_connection_bad_api_key_returns_false():
    c = OctoPrintConnector(_printer())
    client_mock = AsyncMock(get=AsyncMock(return_value=_resp(401)))
    with _patch_client(c, client_mock):
        assert await c.test_connection() is False


@pytest.mark.asyncio
async def test_connection_timeout_returns_false():
    c = OctoPrintConnector(_printer())
    client_mock = AsyncMock(get=AsyncMock(side_effect=httpx.TimeoutException("t")))
    with _patch_client(c, client_mock):
        assert await c.test_connection() is False


@pytest.mark.asyncio
async def test_connection_refused_returns_false():
    c = OctoPrintConnector(_printer())
    client_mock = AsyncMock(get=AsyncMock(side_effect=httpx.ConnectError("refused")))
    with _patch_client(c, client_mock):
        assert await c.test_connection() is False


# ── get_status ────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_get_status_printing():
    c = OctoPrintConnector(_printer())
    with _patch_fetch(_resp(200, _PRINTER_PRINTING), _resp(200, _JOB_PRINTING)):
        with _patch_client(c, AsyncMock()):
            s = await c.get_status()
    assert s.state == PrinterState.PRINTING
    assert s.nozzle_temp_actual == 210.5
    assert s.nozzle_temp_target == 210.0
    assert s.bed_temp_actual == 60.2
    assert s.progress == pytest.approx(0.42, abs=1e-3)
    assert s.time_left_seconds == 1200
    assert s.current_job_name == "benchy.gcode"


@pytest.mark.asyncio
async def test_get_status_idle():
    c = OctoPrintConnector(_printer())
    with _patch_fetch(_resp(200, _PRINTER_IDLE), _resp(200, _JOB_IDLE)):
        with _patch_client(c, AsyncMock()):
            s = await c.get_status()
    assert s.state == PrinterState.IDLE
    assert s.progress is None


@pytest.mark.asyncio
async def test_get_status_timeout_returns_offline():
    c = OctoPrintConnector(_printer())
    with _patch_client(c, AsyncMock()):
        with patch(
            "app.connectors.octoprint._fetch_both",
            new=AsyncMock(side_effect=httpx.TimeoutException("t")),
        ):
            s = await c.get_status()
    assert s.state == PrinterState.OFFLINE
    assert s.nozzle_temp_actual is None


@pytest.mark.asyncio
async def test_get_status_connect_error_returns_offline():
    c = OctoPrintConnector(_printer())
    with _patch_client(c, AsyncMock()):
        with patch(
            "app.connectors.octoprint._fetch_both",
            new=AsyncMock(side_effect=httpx.ConnectError("refused")),
        ):
            s = await c.get_status()
    assert s.state == PrinterState.OFFLINE


@pytest.mark.asyncio
async def test_get_status_5xx_returns_offline():
    c = OctoPrintConnector(_printer())
    with _patch_fetch(_resp(503), _resp(200, _JOB_IDLE)):
        with _patch_client(c, AsyncMock()):
            s = await c.get_status()
    assert s.state == PrinterState.OFFLINE


@pytest.mark.asyncio
async def test_get_status_unknown_state_string():
    data = {"state": {"text": "WeirdState"}, "temperature": {}}
    c = OctoPrintConnector(_printer())
    with _patch_fetch(_resp(200, data), _resp(200, {})):
        with _patch_client(c, AsyncMock()):
            s = await c.get_status()
    assert s.state == PrinterState.UNKNOWN


# ── cancel_job ────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_cancel_job_success():
    c = OctoPrintConnector(_printer())
    client_mock = AsyncMock(post=AsyncMock(return_value=_resp(204)))
    with _patch_client(c, client_mock):
        assert await c.cancel_job() is True


@pytest.mark.asyncio
async def test_cancel_job_non_204_returns_false():
    c = OctoPrintConnector(_printer())
    client_mock = AsyncMock(post=AsyncMock(return_value=_resp(409)))
    with _patch_client(c, client_mock):
        assert await c.cancel_job() is False


@pytest.mark.asyncio
async def test_cancel_job_timeout_returns_false():
    c = OctoPrintConnector(_printer())
    client_mock = AsyncMock(post=AsyncMock(side_effect=httpx.TimeoutException("t")))
    with _patch_client(c, client_mock):
        assert await c.cancel_job() is False
