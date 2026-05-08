"""
Unit tests for PrusaLinkConnector.
HTTP calls stubbed via unittest.mock — no real network needed.
"""

import uuid
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

import httpx
import pytest

from app.connectors.base import JobSubmission, PrinterState
from app.connectors.prusalink import PrusaLinkConnector


def _printer(url="http://prusa.local", api_key="digest-pass", username="maker"):
    return SimpleNamespace(
        id=uuid.uuid4(),
        connector_type="prusalink",
        connection_url=url,
        api_key=api_key,
        username=username,
    )


def _resp(status_code: int, json_body: dict | None = None) -> httpx.Response:
    return httpx.Response(
        status_code=status_code,
        json=json_body or {},
        request=httpx.Request("GET", "http://prusa.local"),
    )


def _patch_client(connector, client_mock):
    cm = AsyncMock()
    cm.__aenter__ = AsyncMock(return_value=client_mock)
    cm.__aexit__ = AsyncMock(return_value=False)
    return patch.object(connector, "_client", return_value=cm)


_PRINTER_PRINTING = {
    "state": {"text": "Printing"},
    "temperature": {
        "tool0": {"actual": 215.0, "target": 215.0},
        "bed": {"actual": 85.0, "target": 85.0},
    },
}

_JOB_PRINTING = {
    "progress": {"completion": 60.0, "printTimeLeft": 600},
    "job": {"file": {"name": "vase.gcode"}},
}

_PRINTER_IDLE = {
    "state": {"text": "Operational"},
    "temperature": {
        "tool0": {"actual": 25.0, "target": 0.0},
        "bed": {"actual": 22.0, "target": 0.0},
    },
}


# ── test_connection ───────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_connection_ok():
    c = PrusaLinkConnector(_printer())
    client_mock = AsyncMock(get=AsyncMock(return_value=_resp(200, {"api": "2.0"})))
    with _patch_client(c, client_mock):
        assert await c.test_connection() is True


@pytest.mark.asyncio
async def test_connection_bad_credentials_returns_false():
    c = PrusaLinkConnector(_printer())
    client_mock = AsyncMock(get=AsyncMock(return_value=_resp(401)))
    with _patch_client(c, client_mock):
        assert await c.test_connection() is False


@pytest.mark.asyncio
async def test_connection_timeout_returns_false():
    c = PrusaLinkConnector(_printer())
    client_mock = AsyncMock(get=AsyncMock(side_effect=httpx.TimeoutException("t")))
    with _patch_client(c, client_mock):
        assert await c.test_connection() is False


@pytest.mark.asyncio
async def test_connection_refused_returns_false():
    c = PrusaLinkConnector(_printer())
    client_mock = AsyncMock(get=AsyncMock(side_effect=httpx.ConnectError("refused")))
    with _patch_client(c, client_mock):
        assert await c.test_connection() is False


# ── get_status ────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_get_status_printing():
    c = PrusaLinkConnector(_printer())
    client_mock = AsyncMock(
        get=AsyncMock(side_effect=[_resp(200, _PRINTER_PRINTING), _resp(200, _JOB_PRINTING)])
    )
    with _patch_client(c, client_mock):
        s = await c.get_status()
    assert s.state == PrinterState.PRINTING
    assert s.nozzle_temp_actual == 215.0
    assert s.bed_temp_actual == 85.0
    assert s.progress == pytest.approx(0.60, abs=1e-3)
    assert s.time_left_seconds == 600
    assert s.current_job_name == "vase.gcode"


@pytest.mark.asyncio
async def test_get_status_idle():
    c = PrusaLinkConnector(_printer())
    client_mock = AsyncMock(
        get=AsyncMock(side_effect=[
            _resp(200, _PRINTER_IDLE),
            _resp(200, {"progress": {}, "job": {"file": {"name": None}}}),
        ])
    )
    with _patch_client(c, client_mock):
        s = await c.get_status()
    assert s.state == PrinterState.IDLE
    assert s.progress is None


@pytest.mark.asyncio
async def test_get_status_timeout_returns_offline():
    c = PrusaLinkConnector(_printer())
    client_mock = AsyncMock(get=AsyncMock(side_effect=httpx.TimeoutException("t")))
    with _patch_client(c, client_mock):
        s = await c.get_status()
    assert s.state == PrinterState.OFFLINE
    assert s.nozzle_temp_actual is None


@pytest.mark.asyncio
async def test_get_status_connect_error_returns_offline():
    c = PrusaLinkConnector(_printer())
    client_mock = AsyncMock(get=AsyncMock(side_effect=httpx.ConnectError("refused")))
    with _patch_client(c, client_mock):
        s = await c.get_status()
    assert s.state == PrinterState.OFFLINE


@pytest.mark.asyncio
async def test_get_status_5xx_returns_offline():
    c = PrusaLinkConnector(_printer())
    client_mock = AsyncMock(
        get=AsyncMock(side_effect=[_resp(503), _resp(200, {})])
    )
    with _patch_client(c, client_mock):
        s = await c.get_status()
    assert s.state == PrinterState.OFFLINE


@pytest.mark.asyncio
async def test_get_status_unknown_state_string():
    data = {"state": {"text": "WeirdState"}, "temperature": {}}
    c = PrusaLinkConnector(_printer())
    client_mock = AsyncMock(
        get=AsyncMock(side_effect=[_resp(200, data), _resp(200, {})])
    )
    with _patch_client(c, client_mock):
        s = await c.get_status()
    assert s.state == PrinterState.UNKNOWN


# ── cancel_job ────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_cancel_job_200_success():
    c = PrusaLinkConnector(_printer())
    client_mock = AsyncMock(delete=AsyncMock(return_value=_resp(200)))
    with _patch_client(c, client_mock):
        assert await c.cancel_job() is True


@pytest.mark.asyncio
async def test_cancel_job_204_success():
    c = PrusaLinkConnector(_printer())
    client_mock = AsyncMock(delete=AsyncMock(return_value=_resp(204)))
    with _patch_client(c, client_mock):
        assert await c.cancel_job() is True


@pytest.mark.asyncio
async def test_cancel_job_non_2xx_returns_false():
    c = PrusaLinkConnector(_printer())
    client_mock = AsyncMock(delete=AsyncMock(return_value=_resp(409)))
    with _patch_client(c, client_mock):
        assert await c.cancel_job() is False


@pytest.mark.asyncio
async def test_cancel_job_timeout_returns_false():
    c = PrusaLinkConnector(_printer())
    client_mock = AsyncMock(delete=AsyncMock(side_effect=httpx.TimeoutException("t")))
    with _patch_client(c, client_mock):
        assert await c.cancel_job() is False
