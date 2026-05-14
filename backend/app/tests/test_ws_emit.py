"""Phase 2 — verify service-side publish calls.

Strategy: patch `app.ws.events.publish` (the sync entrypoint used by emit
helpers) to a recording stub, then call the helpers and a representative
service function. Assert each produced the expected topic / type / data.

We do NOT exercise the full STL pipeline or slicing subprocess here — those
have their own integration tests. We're checking the wire-up between services
and the publish layer.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

import pytest


# ── Recording stub for `publish` ─────────────────────────────────────────────


@pytest.fixture
def recorded_publish(monkeypatch):
    calls: list[tuple[str, str, dict]] = []

    def _record(topic: str, type_: str, data: dict) -> None:
        calls.append((topic, type_, data))

    # Patch the symbol used by emit.py (imported at module load).
    monkeypatch.setattr("app.ws.emit.publish", _record)
    return calls


# ── emit.py helper unit tests ────────────────────────────────────────────────


def test_emit_job_status_publishes_to_job_topic_and_admin_mirror(recorded_publish):
    from app.ws.emit import emit_job_status

    job_id = uuid.uuid4()
    emit_job_status(job_id, status="queued", printer_id=None)

    topics = [c[0] for c in recorded_publish]
    types = [c[1] for c in recorded_publish]
    assert f"job:{job_id}" in topics
    assert "admin:jobs" in topics
    assert types == ["job.status", "job.status"]
    payload = recorded_publish[0][2]
    assert payload["id"] == str(job_id)
    assert payload["status"] == "queued"


def test_emit_stl_status_uses_stl_topic(recorded_publish):
    from app.ws.emit import emit_stl_status

    stl_id = uuid.uuid4()
    emit_stl_status(stl_id, status="analyzing")

    assert len(recorded_publish) == 1
    topic, type_, data = recorded_publish[0]
    assert topic == f"stl:{stl_id}"
    assert type_ == "stl.status"
    assert data == {"id": str(stl_id), "status": "analyzing"}


def test_emit_slicing_progress_uses_job_topic(recorded_publish):
    from app.ws.emit import emit_slicing_progress

    print_job_id = uuid.uuid4()
    emit_slicing_progress(print_job_id, percent=42.5, phase="layers")

    assert len(recorded_publish) == 1
    topic, type_, data = recorded_publish[0]
    assert topic == f"job:{print_job_id}"
    assert type_ == "slicing.progress"
    assert data == {"percent": 42.5, "phase": "layers"}


def test_emit_slicing_status_with_error(recorded_publish):
    from app.ws.emit import emit_slicing_status

    print_job_id = uuid.uuid4()
    sj_id = uuid.uuid4()
    emit_slicing_status(
        print_job_id,
        status="error",
        slicing_job_id=sj_id,
        error_message="prusa-slicer exit 1: bad ini",
    )

    topic, type_, data = recorded_publish[0]
    assert topic == f"job:{print_job_id}"
    assert type_ == "slicing.status"
    assert data["status"] == "error"
    assert data["slicing_job_id"] == str(sj_id)
    assert data["error_message"].startswith("prusa-slicer")


def test_emit_printer_status_uses_printer_topic(recorded_publish):
    from app.ws.emit import emit_printer_status

    printer_id = uuid.uuid4()
    emit_printer_status(printer_id, status="printing", online=True)

    topic, type_, data = recorded_publish[0]
    assert topic == f"printer:{printer_id}"
    assert type_ == "printer.status"
    assert data == {
        "id": str(printer_id),
        "status": "printing",
        "online": True,
    }


# ── Service-level wire-up tests ──────────────────────────────────────────────


def test_slicing_service_cancel_emits_status(recorded_publish, db_session):
    """slicing_service.cancel must emit slicing.status=canceled."""
    from app.models.slicing_job import SlicingJob
    from app.services import slicing_service

    print_job_id = uuid.uuid4()
    sj = SlicingJob(
        id=uuid.uuid4(),
        user_id=uuid.uuid4(),
        print_job_id=print_job_id,
        status="queued",
        started_at=datetime.now(timezone.utc),
    )
    db_session.add(sj)
    db_session.commit()

    slicing_service.cancel(db_session, sj)

    matching = [c for c in recorded_publish if c[1] == "slicing.status"]
    assert len(matching) >= 1
    topic, _, data = matching[-1]
    assert topic == f"job:{print_job_id}"
    assert data["status"] == "canceled"
    assert data["slicing_job_id"] == str(sj.id)


def test_job_service_submit_emits_status(recorded_publish, db_session, monkeypatch):
    """submit_job emits job.status (queued) — verify topic + admin mirror."""
    from app.models.recommendation import Recommendation
    from app.models.stl_file import STLFile
    from app.models.user import User
    from app.schemas.job import JobCreate
    from app.services import job_service

    user = User(
        id=uuid.uuid4(),
        email="u@test.com",
        full_name="u",
        password="x",
        role="operator",
        is_active=True,
    )
    stl = STLFile(
        id=uuid.uuid4(),
        user_id=user.id,
        original_filename="x.stl",
        stored_filename=f"{uuid.uuid4()}.stl",
        file_size_bytes=1,
        status="ready",
    )
    rec = Recommendation(
        id=uuid.uuid4(),
        user_id=user.id,
        stl_file_id=stl.id,
        intended_use="prototype",
        surface_finish="standard",
        needs_flexibility=False,
        strength_required="low",
        budget_priority="cost",
        outdoor_use=False,
        technology="FDM",
        material="PLA",
    )
    db_session.add_all([user, stl, rec])
    db_session.commit()

    payload = JobCreate(
        stl_file_id=stl.id,
        recommendation_id=rec.id,
        priority=3,
        auto_slice=False,
    )
    current_user = {"user_id": str(user.id), "role": "operator"}

    job = job_service.submit_job(db_session, current_user, payload)

    job_topic = f"job:{job.id}"
    job_status_calls = [c for c in recorded_publish if c[1] == "job.status"]
    assert any(c[0] == job_topic for c in job_status_calls)
    assert any(c[0] == "admin:jobs" for c in job_status_calls)


def test_job_service_cancel_emits_canceled(recorded_publish, db_session):
    from app.models.print_job import PrintJob
    from app.models.stl_file import STLFile
    from app.models.user import User
    from app.services import job_service

    user = User(
        id=uuid.uuid4(),
        email="c@test.com",
        full_name="c",
        password="x",
        role="operator",
        is_active=True,
    )
    stl = STLFile(
        id=uuid.uuid4(),
        user_id=user.id,
        original_filename="x.stl",
        stored_filename=f"{uuid.uuid4()}.stl",
        file_size_bytes=1,
        status="ready",
    )
    pj = PrintJob(
        id=uuid.uuid4(),
        user_id=user.id,
        stl_file_id=stl.id,
        recommendation_id=None,
        status="queued",
        priority=3,
    )
    db_session.add_all([user, stl, pj])
    db_session.commit()

    job_service.cancel_job(db_session, {"user_id": str(user.id), "role": "operator"}, pj.id)

    canceled = [
        c for c in recorded_publish
        if c[1] == "job.status" and c[2].get("status") == "canceled"
    ]
    assert canceled, "expected job.status=canceled emit"
    assert any(c[0] == f"job:{pj.id}" for c in canceled)
    assert any(c[0] == "admin:jobs" for c in canceled)


def test_job_service_suspend_resume_emits(recorded_publish, db_session):
    from app.models.print_job import PrintJob
    from app.models.stl_file import STLFile
    from app.models.user import User
    from app.services import job_service

    user = User(
        id=uuid.uuid4(),
        email="s@test.com",
        full_name="s",
        password="x",
        role="admin",
        is_active=True,
    )
    stl = STLFile(
        id=uuid.uuid4(),
        user_id=user.id,
        original_filename="x.stl",
        stored_filename=f"{uuid.uuid4()}.stl",
        file_size_bytes=1,
        status="ready",
    )
    pj = PrintJob(
        id=uuid.uuid4(),
        user_id=user.id,
        stl_file_id=stl.id,
        recommendation_id=None,
        status="queued",
        priority=3,
    )
    db_session.add_all([user, stl, pj])
    db_session.commit()

    job_service.suspend_job(db_session, pj.id)
    paused = [
        c for c in recorded_publish
        if c[1] == "job.status" and c[2].get("status") == "paused"
    ]
    assert paused, "expected job.status=paused emit"

    recorded_publish.clear()
    job_service.resume_job(db_session, pj.id)
    queued = [
        c for c in recorded_publish
        if c[1] == "job.status" and c[2].get("status") == "queued"
    ]
    assert queued, "expected job.status=queued after resume"


def test_slicing_service_create_emits_queued(recorded_publish, db_session):
    """create_slicing_job emits slicing.status=queued for the new row."""
    from app.models.slicing_job import SlicingJob  # noqa: F401 — ensure table
    from app.models.user import User
    from app.models.print_job import PrintJob
    from app.models.stl_file import STLFile
    from app.services import slicing_service

    user = User(
        id=uuid.uuid4(),
        email="u@test.com",
        full_name="u",
        password="x",
        role="operator",
        is_active=True,
    )
    stl = STLFile(
        id=uuid.uuid4(),
        user_id=user.id,
        original_filename="x.stl",
        stored_filename=f"{uuid.uuid4()}.stl",
        file_size_bytes=1,
        status="ready",
    )
    pj = PrintJob(
        id=uuid.uuid4(),
        user_id=user.id,
        stl_file_id=stl.id,
        recommendation_id=None,
        status="queued",
        priority=3,
    )
    db_session.add_all([user, stl, pj])
    db_session.commit()

    sj = slicing_service.create_slicing_job(db_session, print_job=pj, user=user)

    matching = [c for c in recorded_publish if c[1] == "slicing.status"]
    assert len(matching) == 1
    topic, _, data = matching[0]
    assert topic == f"job:{pj.id}"
    assert data["status"] == "queued"
    assert data["slicing_job_id"] == str(sj.id)
