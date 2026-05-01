"""
Unit tests for scheduling_service.find_compatible_printer.

These tests build User/PrintJob/Recommendation/STLFile/Printer rows directly via
db_session — no HTTP calls. The /jobs router lives in Phase B.

Conventions matched from tests/test_stl_upload_flow.py:
- `db_session` fixture from conftest
- User creation via app.core.security.hash_password
"""

import uuid

import pytest

from app.core.security import hash_password
from app.models.print_job import PrintJob
from app.models.printer import Printer
from app.models.recommendation import Recommendation
from app.models.stl_file import STLFile
from app.models.user import User
from app.services.scheduling_service import (
    assign_pending_jobs,
    find_compatible_printer,
)


# ── Fixture: a user we can attach things to ───────────────────────────────────


@pytest.fixture
def scheduling_user(db_session):
    user = User(
        id=uuid.uuid4(),
        email=f"sched_{uuid.uuid4().hex[:8]}@test.com",
        full_name="Scheduling Test User",
        password=hash_password("password123"),
        role="operator",
        is_active=True,
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


# ── Helpers ───────────────────────────────────────────────────────────────────


def _make_stl(
    db_session,
    user_id,
    *,
    bbox=(100.0, 100.0, 100.0),
):
    stl = STLFile(
        id=uuid.uuid4(),
        user_id=user_id,
        original_filename="test.stl",
        stored_filename=f"{uuid.uuid4()}.stl",
        file_size_bytes=1024,
        bbox_x_mm=bbox[0],
        bbox_y_mm=bbox[1],
        bbox_z_mm=bbox[2],
        status="ready",
    )
    db_session.add(stl)
    db_session.commit()
    db_session.refresh(stl)
    return stl


def _make_recommendation(
    db_session,
    user_id,
    stl_id,
    *,
    technology="FDM",
    material="PLA",
):
    rec = Recommendation(
        id=uuid.uuid4(),
        user_id=user_id,
        stl_file_id=stl_id,
        intended_use="functional",
        surface_finish="standard",
        needs_flexibility=False,
        strength_required="medium",
        budget_priority="quality",
        outdoor_use=False,
        technology=technology,
        material=material,
    )
    db_session.add(rec)
    db_session.commit()
    db_session.refresh(rec)
    return rec


def _make_printer(
    db_session,
    *,
    name=None,
    technology="FDM",
    materials=None,
    status="idle",
    build_volume=(250.0, 250.0, 250.0),
):
    bx, by, bz = build_volume if build_volume else (None, None, None)
    printer = Printer(
        id=uuid.uuid4(),
        name=name or f"Printer-{uuid.uuid4().hex[:6]}",
        technology=technology,
        materials_supported=materials if materials is not None else ["PLA", "PETG"],
        status=status,
        build_volume_x=bx,
        build_volume_y=by,
        build_volume_z=bz,
        connector_type="mock",
    )
    db_session.add(printer)
    db_session.commit()
    db_session.refresh(printer)
    return printer


def _make_job(db_session, user_id, stl_id, rec_id, *, priority=3):
    job = PrintJob(
        id=uuid.uuid4(),
        user_id=user_id,
        stl_file_id=stl_id,
        recommendation_id=rec_id,
        status="queued",
        priority=priority,
    )
    db_session.add(job)
    db_session.commit()
    db_session.refresh(job)
    return job


# ── Tests: find_compatible_printer ────────────────────────────────────────────


def test_finds_printer_when_everything_matches(db_session, scheduling_user):
    stl = _make_stl(db_session, scheduling_user.id)
    rec = _make_recommendation(db_session, scheduling_user.id, stl.id, technology="FDM", material="PLA")
    job = _make_job(db_session, scheduling_user.id, stl.id, rec.id)

    printer = _make_printer(db_session, technology="FDM", materials=["PLA", "PETG"])

    match = find_compatible_printer(db_session, job)
    assert match is not None
    assert match.id == printer.id


def test_rejects_wrong_technology(db_session, scheduling_user):
    stl = _make_stl(db_session, scheduling_user.id)
    rec = _make_recommendation(db_session, scheduling_user.id, stl.id, technology="SLA", material="Resin-Std")
    job = _make_job(db_session, scheduling_user.id, stl.id, rec.id)

    # Only an FDM printer available → no match for SLA job
    _make_printer(db_session, technology="FDM", materials=["PLA"])

    assert find_compatible_printer(db_session, job) is None


def test_rejects_unsupported_material(db_session, scheduling_user):
    stl = _make_stl(db_session, scheduling_user.id)
    rec = _make_recommendation(db_session, scheduling_user.id, stl.id, technology="FDM", material="TPU")
    job = _make_job(db_session, scheduling_user.id, stl.id, rec.id)

    # Printer is FDM but doesn't support TPU
    _make_printer(db_session, technology="FDM", materials=["PLA", "PETG"])

    assert find_compatible_printer(db_session, job) is None


def test_rejects_when_bbox_too_large(db_session, scheduling_user):
    stl = _make_stl(db_session, scheduling_user.id, bbox=(300.0, 100.0, 100.0))
    rec = _make_recommendation(db_session, scheduling_user.id, stl.id)
    job = _make_job(db_session, scheduling_user.id, stl.id, rec.id)

    _make_printer(db_session, build_volume=(250.0, 250.0, 250.0))

    assert find_compatible_printer(db_session, job) is None


def test_permissive_when_printer_volume_unknown(db_session, scheduling_user):
    stl = _make_stl(db_session, scheduling_user.id, bbox=(500.0, 500.0, 500.0))  # huge
    rec = _make_recommendation(db_session, scheduling_user.id, stl.id)
    job = _make_job(db_session, scheduling_user.id, stl.id, rec.id)

    printer = _make_printer(db_session, build_volume=None)  # unknown volume

    match = find_compatible_printer(db_session, job)
    assert match is not None
    assert match.id == printer.id


def test_skips_non_idle_printers(db_session, scheduling_user):
    stl = _make_stl(db_session, scheduling_user.id)
    rec = _make_recommendation(db_session, scheduling_user.id, stl.id)
    job = _make_job(db_session, scheduling_user.id, stl.id, rec.id)

    _make_printer(db_session, status="printing")
    _make_printer(db_session, status="offline")
    _make_printer(db_session, status="error")

    assert find_compatible_printer(db_session, job) is None


# ── Tests: assign_pending_jobs ────────────────────────────────────────────────


def test_assign_pending_jobs_schedules_compatible(db_session, scheduling_user):
    stl = _make_stl(db_session, scheduling_user.id)
    rec = _make_recommendation(db_session, scheduling_user.id, stl.id)
    job = _make_job(db_session, scheduling_user.id, stl.id, rec.id)
    printer = _make_printer(db_session)

    scheduled = assign_pending_jobs(db_session)

    assert len(scheduled) == 1
    db_session.refresh(job)
    db_session.refresh(printer)
    assert job.status == "scheduled"
    assert job.printer_id == printer.id
    assert job.scheduled_at is not None
    assert printer.status == "printing"


def test_assign_pending_jobs_leaves_unmatchable_queued(db_session, scheduling_user):
    stl = _make_stl(db_session, scheduling_user.id)
    rec = _make_recommendation(db_session, scheduling_user.id, stl.id, technology="SLA", material="Resin-Std")
    job = _make_job(db_session, scheduling_user.id, stl.id, rec.id)

    # Only FDM printers available
    _make_printer(db_session, technology="FDM", materials=["PLA"])

    scheduled = assign_pending_jobs(db_session)

    assert scheduled == []
    db_session.refresh(job)
    assert job.status == "queued"
    assert job.printer_id is None


def test_assign_pending_jobs_respects_priority(db_session, scheduling_user):
    stl = _make_stl(db_session, scheduling_user.id)
    rec = _make_recommendation(db_session, scheduling_user.id, stl.id)

    low = _make_job(db_session, scheduling_user.id, stl.id, rec.id, priority=1)
    high = _make_job(db_session, scheduling_user.id, stl.id, rec.id, priority=5)

    # Only one printer — high priority job should win
    printer = _make_printer(db_session)

    scheduled = assign_pending_jobs(db_session)

    assert len(scheduled) == 1
    assert scheduled[0].id == high.id

    db_session.refresh(low)
    assert low.status == "queued"  # still queued, no printer left