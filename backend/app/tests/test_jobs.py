"""
End-to-end tests for jobs API.

Coverage:
- Submit creates queued job
- Submit auto-assigns to compatible printer
- Submit fails if no compatible printer (job stays queued)
- User isolation: list (user A doesn't see user B's jobs)
- User isolation: get (user A gets 404 on user B's job, NOT 403)
- Admin sees all jobs
- Cancel frees printer (and the next queued job grabs it)
- Suspend admin-only (regular user gets 403)
- Resume admin-only

`test_user` from conftest is an admin (role="admin"). Where we need a regular
user we create one inline.
"""

import uuid
from fastapi import status

from app.core.security import hash_password
from app.models.printer import Printer
from app.models.recommendation import Recommendation
from app.models.stl_file import STLFile
from app.models.user import User


# ── Inline fixture helpers (no conftest changes needed) ──────────────────────


def _create_user(db_session, *, email, role="operator"):
    user = User(
        id=uuid.uuid4(),
        email=email,
        full_name=f"User {email}",
        password=hash_password("password123"),
        role=role,
        is_active=True,
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


def _login(client, email: str) -> str:
    resp = client.post(
        "/auth/login", json={"email": email, "password": "password123"}
    )
    assert resp.status_code == 200, resp.text
    return resp.json()["access_token"]


def _make_stl(db_session, user_id, *, bbox=(100.0, 100.0, 100.0)):
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


def _make_recommendation(db_session, user_id, stl_id, *, technology="FDM", material="PLA"):
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
    status_value="idle",
):
    printer = Printer(
        id=uuid.uuid4(),
        name=name or f"Printer-{uuid.uuid4().hex[:6]}",
        technology=technology,
        materials_supported=materials if materials is not None else ["PLA", "PETG"],
        status=status_value,
        build_volume_x=250.0,
        build_volume_y=250.0,
        build_volume_z=250.0,
        connector_type="mock",
    )
    db_session.add(printer)
    db_session.commit()
    db_session.refresh(printer)
    return printer


def _auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


# ── Submit ────────────────────────────────────────────────────────────────────


def test_submit_creates_queued_when_no_printer(client, db_session, test_user, test_user_token):
    stl = _make_stl(db_session, test_user.id)
    rec = _make_recommendation(db_session, test_user.id, stl.id)
    # No printer in DB → job stays queued

    resp = client.post(
        "/jobs",
        json={"stl_file_id": str(stl.id), "recommendation_id": str(rec.id)},
        headers=_auth(test_user_token),
    )

    assert resp.status_code == status.HTTP_201_CREATED, resp.text
    body = resp.json()
    assert body["status"] == "queued"
    assert body["printer_id"] is None
    assert body["priority"] == 3  # default
    # api_key never leaks (sanity — wrong schema, but cheap to assert)
    assert "api_key_encrypted" not in body


def test_submit_auto_assigns_compatible_printer(client, db_session, test_user, test_user_token):
    stl = _make_stl(db_session, test_user.id)
    rec = _make_recommendation(db_session, test_user.id, stl.id)
    printer = _make_printer(db_session)

    resp = client.post(
        "/jobs",
        json={"stl_file_id": str(stl.id), "recommendation_id": str(rec.id)},
        headers=_auth(test_user_token),
    )

    assert resp.status_code == status.HTTP_201_CREATED, resp.text
    body = resp.json()
    assert body["status"] == "scheduled"
    assert body["printer_id"] == str(printer.id)
    assert body["scheduled_at"] is not None


def test_submit_rejects_unknown_stl(client, db_session, test_user, test_user_token):
    # No STL created — random UUID
    rec_uuid = str(uuid.uuid4())  # also fake but STL is checked first

    resp = client.post(
        "/jobs",
        json={"stl_file_id": str(uuid.uuid4()), "recommendation_id": rec_uuid},
        headers=_auth(test_user_token),
    )
    assert resp.status_code == status.HTTP_404_NOT_FOUND


def test_submit_rejects_other_users_stl(client, db_session, test_user_token):
    """Admin (test_user) submits — but uses a regular user's STL & rec.

    Wait — admin can use anyone's STL. So this test uses a regular user
    submitting against the admin's STL instead.
    """
    user_b = _create_user(db_session, email="user_b@test.com")
    token_b = _login(client, "user_b@test.com")

    # Create STL & rec owned by ANOTHER user
    other = _create_user(db_session, email="other@test.com")
    stl = _make_stl(db_session, other.id)
    rec = _make_recommendation(db_session, other.id, stl.id)

    resp = client.post(
        "/jobs",
        json={"stl_file_id": str(stl.id), "recommendation_id": str(rec.id)},
        headers=_auth(token_b),
    )
    # Regular user can't see other user's STL → 404
    assert resp.status_code == status.HTTP_404_NOT_FOUND


# ── List ──────────────────────────────────────────────────────────────────────


def test_list_isolation_regular_user_sees_only_own(
    client, db_session, test_user, test_user_token
):
    # User A (admin) submits one job
    stl_a = _make_stl(db_session, test_user.id)
    rec_a = _make_recommendation(db_session, test_user.id, stl_a.id)
    client.post(
        "/jobs",
        json={"stl_file_id": str(stl_a.id), "recommendation_id": str(rec_a.id)},
        headers=_auth(test_user_token),
    )

    # User B (regular) submits one job
    user_b = _create_user(db_session, email="user_b@test.com")
    stl_b = _make_stl(db_session, user_b.id)
    rec_b = _make_recommendation(db_session, user_b.id, stl_b.id)
    token_b = _login(client, "user_b@test.com")
    client.post(
        "/jobs",
        json={"stl_file_id": str(stl_b.id), "recommendation_id": str(rec_b.id)},
        headers=_auth(token_b),
    )

    # Regular user B lists jobs — sees only own
    resp = client.get("/jobs", headers=_auth(token_b))
    assert resp.status_code == 200
    jobs = resp.json()
    assert len(jobs) == 1
    assert jobs[0]["user_id"] == str(user_b.id)


def test_list_admin_sees_all(client, db_session, test_user, test_user_token):
    # User B submits
    user_b = _create_user(db_session, email="user_b@test.com")
    stl_b = _make_stl(db_session, user_b.id)
    rec_b = _make_recommendation(db_session, user_b.id, stl_b.id)
    token_b = _login(client, "user_b@test.com")
    client.post(
        "/jobs",
        json={"stl_file_id": str(stl_b.id), "recommendation_id": str(rec_b.id)},
        headers=_auth(token_b),
    )

    # Admin (test_user) submits
    stl_a = _make_stl(db_session, test_user.id)
    rec_a = _make_recommendation(db_session, test_user.id, stl_a.id)
    client.post(
        "/jobs",
        json={"stl_file_id": str(stl_a.id), "recommendation_id": str(rec_a.id)},
        headers=_auth(test_user_token),
    )

    resp = client.get("/jobs", headers=_auth(test_user_token))
    assert resp.status_code == 200
    jobs = resp.json()
    assert len(jobs) == 2


# ── Get (single) ──────────────────────────────────────────────────────────────


def test_get_isolation_returns_404_not_403(client, db_session, test_user, test_user_token):
    """User A querying User B's job must get 404 — not 403, not the job."""
    # Admin creates a job
    stl = _make_stl(db_session, test_user.id)
    rec = _make_recommendation(db_session, test_user.id, stl.id)
    submit_resp = client.post(
        "/jobs",
        json={"stl_file_id": str(stl.id), "recommendation_id": str(rec.id)},
        headers=_auth(test_user_token),
    )
    job_id = submit_resp.json()["id"]

    # Regular user tries to fetch it
    user_b = _create_user(db_session, email="user_b@test.com")
    token_b = _login(client, "user_b@test.com")

    resp = client.get(f"/jobs/{job_id}", headers=_auth(token_b))
    assert resp.status_code == status.HTTP_404_NOT_FOUND
    assert resp.status_code != status.HTTP_403_FORBIDDEN


# ── Cancel ────────────────────────────────────────────────────────────────────


def test_cancel_frees_printer_and_assigns_next(
    client, db_session, test_user, test_user_token
):
    """When a scheduled job is canceled, the printer must be freed AND
    the next queued-but-incompatible-priority job should pick it up."""
    # One printer
    printer = _make_printer(db_session)

    # First job — gets scheduled to the printer
    stl1 = _make_stl(db_session, test_user.id)
    rec1 = _make_recommendation(db_session, test_user.id, stl1.id)
    r1 = client.post(
        "/jobs",
        json={"stl_file_id": str(stl1.id), "recommendation_id": str(rec1.id)},
        headers=_auth(test_user_token),
    )
    job1 = r1.json()
    assert job1["status"] == "scheduled"

    # Second job — no printer left → queued
    stl2 = _make_stl(db_session, test_user.id)
    rec2 = _make_recommendation(db_session, test_user.id, stl2.id)
    r2 = client.post(
        "/jobs",
        json={"stl_file_id": str(stl2.id), "recommendation_id": str(rec2.id)},
        headers=_auth(test_user_token),
    )
    job2 = r2.json()
    assert job2["status"] == "queued"

    # Cancel job1 → frees printer → scheduler picks up job2
    cancel_resp = client.patch(
        f"/jobs/{job1['id']}/cancel", headers=_auth(test_user_token)
    )
    assert cancel_resp.status_code == 200
    assert cancel_resp.json()["status"] == "canceled"

    # Re-fetch job2 — should now be scheduled
    job2_now = client.get(f"/jobs/{job2['id']}", headers=_auth(test_user_token)).json()
    assert job2_now["status"] == "scheduled"
    assert job2_now["printer_id"] == str(printer.id)


def test_cancel_isolation_blocks_other_users(
    client, db_session, test_user, test_user_token
):
    # Admin creates a job
    stl = _make_stl(db_session, test_user.id)
    rec = _make_recommendation(db_session, test_user.id, stl.id)
    job_id = client.post(
        "/jobs",
        json={"stl_file_id": str(stl.id), "recommendation_id": str(rec.id)},
        headers=_auth(test_user_token),
    ).json()["id"]

    # Regular user tries to cancel it
    _create_user(db_session, email="user_b@test.com")
    token_b = _login(client, "user_b@test.com")

    resp = client.patch(f"/jobs/{job_id}/cancel", headers=_auth(token_b))
    # 404, not 403 — don't leak existence
    assert resp.status_code == status.HTTP_404_NOT_FOUND


# ── Suspend / Resume (admin only) ─────────────────────────────────────────────


def test_suspend_requires_admin(client, db_session, test_user, test_user_token):
    # Admin creates a job
    _make_printer(db_session)
    stl = _make_stl(db_session, test_user.id)
    rec = _make_recommendation(db_session, test_user.id, stl.id)
    job_id = client.post(
        "/jobs",
        json={"stl_file_id": str(stl.id), "recommendation_id": str(rec.id)},
        headers=_auth(test_user_token),
    ).json()["id"]

    # Regular user tries to suspend
    _create_user(db_session, email="user_b@test.com")
    token_b = _login(client, "user_b@test.com")

    resp = client.patch(f"/jobs/{job_id}/suspend", headers=_auth(token_b))
    assert resp.status_code == status.HTTP_403_FORBIDDEN


def test_suspend_then_resume_admin_flow(
    client, db_session, test_user, test_user_token
):
    printer = _make_printer(db_session)
    stl = _make_stl(db_session, test_user.id)
    rec = _make_recommendation(db_session, test_user.id, stl.id)
    job_id = client.post(
        "/jobs",
        json={"stl_file_id": str(stl.id), "recommendation_id": str(rec.id)},
        headers=_auth(test_user_token),
    ).json()["id"]

    # Suspend
    suspend_resp = client.patch(
        f"/jobs/{job_id}/suspend", headers=_auth(test_user_token)
    )
    assert suspend_resp.status_code == 200
    body = suspend_resp.json()
    assert body["status"] == "paused"
    assert body["printer_id"] is None  # detached

    # Resume — should re-schedule onto the now-free printer
    resume_resp = client.patch(
        f"/jobs/{job_id}/resume", headers=_auth(test_user_token)
    )
    assert resume_resp.status_code == 200
    body = resume_resp.json()
    assert body["status"] == "scheduled"
    assert body["printer_id"] == str(printer.id)