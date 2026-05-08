"""
Full lifecycle tests for MockConnector.
No network — all state is in-process.
"""

import uuid
from types import SimpleNamespace

import pytest

from app.connectors.base import JobSubmission, PrinterState
from app.connectors.mock import MockConnector, _state


def _printer():
    return SimpleNamespace(id=uuid.uuid4())


@pytest.fixture(autouse=True)
def clear_mock_state():
    _state.clear()
    yield
    _state.clear()


@pytest.mark.asyncio
async def test_connection_always_true():
    assert await MockConnector(_printer()).test_connection() is True


@pytest.mark.asyncio
async def test_initial_status_is_idle():
    c = MockConnector(_printer())
    s = await c.get_status()
    assert s.state == PrinterState.IDLE
    assert s.progress is None
    assert s.current_job_name is None


@pytest.mark.asyncio
async def test_submit_transitions_to_printing():
    c = MockConnector(_printer())
    result = await c.submit_job(JobSubmission(file_path="/tmp/x.gcode", file_name="x.gcode"))
    assert result.success is True
    assert result.remote_job_id is not None
    s = await c.get_status()
    assert s.state == PrinterState.PRINTING
    assert s.current_job_name == "x.gcode"
    assert s.progress == pytest.approx(0.05, abs=1e-9)


@pytest.mark.asyncio
async def test_progress_increases_each_poll():
    c = MockConnector(_printer())
    await c.submit_job(JobSubmission(file_path="/tmp/x.gcode", file_name="x.gcode"))
    s1 = await c.get_status()
    s2 = await c.get_status()
    assert s2.progress > s1.progress


@pytest.mark.asyncio
async def test_cancel_returns_to_idle():
    c = MockConnector(_printer())
    await c.submit_job(JobSubmission(file_path="/tmp/x.gcode", file_name="x.gcode"))
    assert await c.cancel_job() is True
    s = await c.get_status()
    assert s.state == PrinterState.IDLE
    assert s.progress is None
    assert s.current_job_name is None


@pytest.mark.asyncio
async def test_full_lifecycle():
    c = MockConnector(_printer())

    # idle
    s = await c.get_status()
    assert s.state == PrinterState.IDLE

    # submit
    r = await c.submit_job(JobSubmission(file_path="/tmp/f.gcode", file_name="f.gcode"))
    assert r.success is True

    # printing
    s = await c.get_status()
    assert s.state == PrinterState.PRINTING

    # cancel
    await c.cancel_job()

    # back to idle
    s = await c.get_status()
    assert s.state == PrinterState.IDLE


@pytest.mark.asyncio
async def test_two_printers_independent_state():
    c1 = MockConnector(_printer())
    c2 = MockConnector(_printer())
    await c1.submit_job(JobSubmission(file_path="/tmp/a.gcode", file_name="a.gcode"))
    s2 = await c2.get_status()
    assert s2.state == PrinterState.IDLE


@pytest.mark.asyncio
async def test_temperature_fluctuates_near_target():
    c = MockConnector(_printer())
    s = await c.get_status()
    assert 205 <= s.nozzle_temp_actual <= 215
    assert 57 <= s.bed_temp_actual <= 63
    assert s.nozzle_temp_target == 210.0
    assert s.bed_temp_target == 60.0


@pytest.mark.asyncio
async def test_job_completes_when_progress_reaches_100():
    c = MockConnector(_printer())
    await c.submit_job(JobSubmission(file_path="/tmp/x.gcode", file_name="x.gcode"))
    # drive progress to 1.0 by polling 20 times (20 * 0.05 = 1.0)
    for _ in range(20):
        s = await c.get_status()
    assert s.state == PrinterState.IDLE
    assert s.progress is None
