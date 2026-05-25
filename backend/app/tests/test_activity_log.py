"""Tests for ActivityLog (US-24) — service + admin endpoint."""

import uuid
from datetime import datetime, timedelta, timezone

import pytest

from app.models.activity_log import ActivityLog
from app.models.user import User
from app.core.security import hash_password
from app.services import activity_log_service


# ── Service tests ────────────────────────────────────────────────────────────


def test_log_persists_row(db_session):
    row = activity_log_service.log(
        db_session,
        event_type="auth",
        message="Connexion réussie",
        severity="info",
    )
    db_session.commit()
    assert row is not None
    assert row.id is not None
    assert row.message == "Connexion réussie"
    assert row.event_type == "auth"


def test_log_never_raises_on_bad_input(db_session, monkeypatch):
    """Service must swallow DB errors so audit failures don't break callers."""
    from app.services import activity_log_service as svc

    def boom(*_a, **_k):
        raise RuntimeError("db down")

    monkeypatch.setattr(svc.ActivityLog, "__init__", lambda *a, **k: (_ for _ in ()).throw(RuntimeError("boom")))
    result = svc.log(db_session, event_type="job", message="test")
    assert result is None


def test_query_filters_and_paginates(db_session):
    base = datetime.now(timezone.utc) - timedelta(hours=1)
    for i in range(5):
        activity_log_service.log(
            db_session,
            event_type="job" if i % 2 == 0 else "printer",
            message=f"event {i}",
            severity="info" if i < 3 else "warning",
        )
    db_session.commit()

    rows, total = activity_log_service.query(db_session, limit=10)
    assert total == 5
    assert len(rows) == 5

    rows, total = activity_log_service.query(db_session, event_type="job")
    assert total == 3
    assert all(r.event_type == "job" for r in rows)

    rows, total = activity_log_service.query(db_session, severity="warning")
    assert total == 2

    rows, _ = activity_log_service.query(db_session, limit=2, offset=2)
    assert len(rows) == 2


def test_query_date_range(db_session):
    now = datetime.now(timezone.utc)
    # Insert one old row by direct construction
    old = ActivityLog(
        event_type="auth",
        message="old",
        timestamp=now - timedelta(days=3),
    )
    db_session.add(old)
    activity_log_service.log(db_session, event_type="auth", message="new")
    db_session.commit()

    rows, total = activity_log_service.query(
        db_session, date_from=now - timedelta(days=1)
    )
    assert total == 1
    assert rows[0].message == "new"


# ── Endpoint tests ───────────────────────────────────────────────────────────


@pytest.fixture
def operator_token(client, db_session):
    op = User(
        id=uuid.uuid4(),
        email="op@test.com",
        full_name="Op",
        password=hash_password("password123"),
        role="operator",
        is_active=True,
    )
    db_session.add(op)
    db_session.commit()
    r = client.post("/auth/login", json={"email": op.email, "password": "password123"})
    return r.json()["access_token"]


def test_admin_activity_endpoint_admin_only(client, operator_token):
    r = client.get(
        "/admin/activity",
        headers={"Authorization": f"Bearer {operator_token}"},
    )
    assert r.status_code == 403


def test_admin_activity_returns_filtered_page(client, test_user_token, db_session):
    activity_log_service.log(db_session, event_type="auth", message="login a")
    activity_log_service.log(db_session, event_type="job", message="submit b")
    activity_log_service.log(db_session, event_type="job", message="done c", severity="success")
    db_session.commit()

    r = client.get(
        "/admin/activity?event_type=job&limit=10",
        headers={"Authorization": f"Bearer {test_user_token}"},
    )
    assert r.status_code == 200
    body = r.json()
    assert body["total"] == 2
    assert all(item["event_type"] == "job" for item in body["items"])
    assert body["limit"] == 10
    assert body["offset"] == 0
