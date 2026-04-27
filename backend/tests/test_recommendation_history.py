"""
Tests for:
  GET /recommend/history           — list, filters (technology, material, combined)
  GET /recommend/{recommendation_id} — ownership enforcement (403 / 404)
"""

import uuid
from datetime import datetime, timezone, timedelta

import pytest
from fastapi import status

from app.core.security import hash_password
from app.models.user import User
from app.models.stl_file import STLFile
from app.models.recommendation import Recommendation


# ── Helpers ───────────────────────────────────────────────────────────────────

def auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _create_user(db_session, email: str, password: str) -> User:
    user = User(
        id=uuid.uuid4(),
        email=email,
        full_name=email.split("@")[0],
        password=hash_password(password),
        role="operator",
        is_active=True,
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


def _login(client, email: str, password: str) -> str:
    r = client.post("/auth/login", json={"email": email, "password": password})
    assert r.status_code == 200, r.text
    return r.json()["access_token"]


# ── Fixtures ──────────────────────────────────────────────────────────────────

@pytest.fixture
def user_a(db_session):
    return _create_user(db_session, "user_a@test.com", "pass_a_123")


@pytest.fixture
def token_a(client, user_a):
    return _login(client, user_a.email, "pass_a_123")


@pytest.fixture
def user_b(db_session):
    return _create_user(db_session, "user_b@test.com", "pass_b_123")


@pytest.fixture
def token_b(client, user_b):
    return _login(client, user_b.email, "pass_b_123")


@pytest.fixture
def stl_file_a(db_session, user_a):
    f = STLFile(
        id=uuid.uuid4(),
        user_id=user_a.id,
        original_filename="cube.stl",
        stored_filename=f"cube_{uuid.uuid4().hex}.stl",
        file_size_bytes=1024,
        status="ready",
    )
    db_session.add(f)
    db_session.commit()
    db_session.refresh(f)
    return f


@pytest.fixture
def make_rec(db_session, user_a, stl_file_a):
    """
    Factory that inserts a Recommendation row directly into the DB.
    Defaults to user_a / stl_file_a / FDM / PLA.
    Pass `created_at` to control sort order.
    """

    def _factory(
        technology: str = "FDM",
        material: str = "PLA",
        created_at: datetime | None = None,
        user_id=None,
    ) -> Recommendation:
        rec = Recommendation(
            id=uuid.uuid4(),
            user_id=user_id if user_id is not None else user_a.id,
            stl_file_id=stl_file_a.id,
            intended_use="functional",
            surface_finish="standard",
            needs_flexibility=False,
            strength_required="medium",
            budget_priority="cost",
            outdoor_use=False,
            technology=technology,
            material=material,
            needs_clarification=False,
            created_at=created_at or datetime.now(timezone.utc),
        )
        db_session.add(rec)
        db_session.commit()
        db_session.refresh(rec)
        return rec

    return _factory


# ── Tests: GET /recommend/history ─────────────────────────────────────────────

def test_history_empty(client, token_a):
    r = client.get("/recommend/history", headers=auth(token_a))
    assert r.status_code == status.HTTP_200_OK
    data = r.json()
    assert data["total"] == 0
    assert data["items"] == []


def test_history_returns_items_sorted_descending(client, token_a, make_rec):
    older = make_rec(created_at=datetime.now(timezone.utc) - timedelta(hours=2))
    newer = make_rec(created_at=datetime.now(timezone.utc))

    r = client.get("/recommend/history", headers=auth(token_a))
    assert r.status_code == status.HTTP_200_OK
    data = r.json()
    assert data["total"] == 2
    assert [item["id"] for item in data["items"]] == [str(newer.id), str(older.id)]


def test_history_filter_technology(client, token_a, make_rec):
    make_rec(technology="FDM", material="PLA")
    make_rec(technology="SLA", material="Resin-Std")

    r = client.get("/recommend/history?technology=FDM", headers=auth(token_a))
    assert r.status_code == status.HTTP_200_OK
    data = r.json()
    assert data["total"] == 1
    assert data["items"][0]["technology"] == "FDM"


def test_history_filter_technology_no_match(client, token_a, make_rec):
    make_rec(technology="FDM")

    r = client.get("/recommend/history?technology=SLA", headers=auth(token_a))
    assert r.status_code == status.HTTP_200_OK
    assert r.json()["total"] == 0


def test_history_filter_material(client, token_a, make_rec):
    make_rec(technology="FDM", material="PLA")
    make_rec(technology="FDM", material="PETG")

    r = client.get("/recommend/history?material=PETG", headers=auth(token_a))
    assert r.status_code == status.HTTP_200_OK
    data = r.json()
    assert data["total"] == 1
    assert data["items"][0]["material"] == "PETG"


def test_history_filter_combined(client, token_a, make_rec):
    make_rec(technology="FDM", material="PLA")
    make_rec(technology="FDM", material="PETG")
    make_rec(technology="SLA", material="PLA")

    r = client.get("/recommend/history?technology=FDM&material=PLA", headers=auth(token_a))
    assert r.status_code == status.HTTP_200_OK
    data = r.json()
    assert data["total"] == 1
    assert data["items"][0]["technology"] == "FDM"
    assert data["items"][0]["material"] == "PLA"


def test_history_scoped_to_current_user(client, token_b, make_rec):
    """user_b must not see user_a's recommendations."""
    make_rec()  # owned by user_a

    r = client.get("/recommend/history", headers=auth(token_b))
    assert r.status_code == status.HTTP_200_OK
    assert r.json()["total"] == 0


def test_history_requires_auth(client):
    r = client.get("/recommend/history")
    assert r.status_code in (status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN)


# ── Tests: GET /recommend/{recommendation_id} ─────────────────────────────────

def test_get_by_id_success(client, token_a, make_rec):
    rec = make_rec()

    r = client.get(f"/recommend/{rec.id}", headers=auth(token_a))
    assert r.status_code == status.HTTP_200_OK
    assert r.json()["id"] == str(rec.id)


def test_get_by_id_forbidden(client, token_b, make_rec):
    """A recommendation owned by user_a must return 403 for user_b."""
    rec = make_rec()  # owned by user_a

    r = client.get(f"/recommend/{rec.id}", headers=auth(token_b))
    assert r.status_code == status.HTTP_403_FORBIDDEN


def test_get_by_id_not_found(client, token_a):
    r = client.get(f"/recommend/{uuid.uuid4()}", headers=auth(token_a))
    assert r.status_code == status.HTTP_404_NOT_FOUND


def test_get_by_id_requires_auth(client, make_rec):
    rec = make_rec()

    r = client.get(f"/recommend/{rec.id}")
    assert r.status_code in (status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN)
