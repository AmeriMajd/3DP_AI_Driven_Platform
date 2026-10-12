"""Phase 1 WebSocket skeleton tests.

Covers: handshake auth, subscribe ack, forbidden, invalid topic, ping/pong,
unsubscribe round-trip. Pub/sub fanout is covered in Phase 2 with real Redis.
"""

from __future__ import annotations

import uuid

import pytest
from starlette.testclient import WebSocketTestSession
from starlette.websockets import WebSocketDisconnect

from app.core.security import hash_password
from app.models.user import User


# ── Stub the Redis-touching parts so Phase 1 tests don't need a Redis broker ──


@pytest.fixture(autouse=True)
def _patch_ws_redis(monkeypatch):
    async def _noop():
        return None

    async def _noop_get(_topic):
        return None

    monkeypatch.setattr("app.ws.events.start_subscriber", _noop)
    monkeypatch.setattr("app.ws.events.stop_subscriber", _noop)
    monkeypatch.setattr("app.ws.events.get_last_event", _noop_get)


# ── Helpers ──────────────────────────────────────────────────────────────────


def _make_user(db_session, *, email: str, role: str) -> User:
    user = User(
        id=uuid.uuid4(),
        email=email,
        full_name=f"u-{role}",
        password=hash_password("password123"),
        role=role,
        is_active=True,
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


def _login(client, email: str) -> str:
    r = client.post(
        "/auth/login", json={"email": email, "password": "password123"}
    )
    assert r.status_code == 200, r.text
    return r.json()["access_token"]


# ── Tests ────────────────────────────────────────────────────────────────────


def test_ws_rejects_invalid_token(client):
    with pytest.raises(WebSocketDisconnect) as exc:
        with client.websocket_connect("/ws?token=not-a-jwt") as _:
            pass
    assert exc.value.code == 4401


def test_ws_admin_subscribe_admin_jobs_ack(client, db_session):
    _make_user(db_session, email="a@test.com", role="admin")
    token = _login(client, "a@test.com")

    with client.websocket_connect(f"/ws?token={token}") as ws:  # type: WebSocketTestSession
        ws.send_json({"op": "subscribe", "topic": "admin:jobs"})
        msg = ws.receive_json()
        assert msg == {"op": "subscribed", "topic": "admin:jobs"}


def test_ws_operator_forbidden_on_admin_topic(client, db_session):
    _make_user(db_session, email="op@test.com", role="operator")
    token = _login(client, "op@test.com")

    with client.websocket_connect(f"/ws?token={token}") as ws:
        ws.send_json({"op": "subscribe", "topic": "admin:jobs"})
        msg = ws.receive_json()
        assert msg["op"] == "error"
        assert msg["code"] == "forbidden"
        assert msg["topic"] == "admin:jobs"


def test_ws_invalid_topic(client, db_session):
    _make_user(db_session, email="a@test.com", role="admin")
    token = _login(client, "a@test.com")

    with client.websocket_connect(f"/ws?token={token}") as ws:
        ws.send_json({"op": "subscribe", "topic": "bogus:foo"})
        msg = ws.receive_json()
        assert msg["op"] == "error"
        assert msg["code"] == "invalid_topic"


def test_ws_ping_pong(client, db_session):
    _make_user(db_session, email="a@test.com", role="admin")
    token = _login(client, "a@test.com")

    with client.websocket_connect(f"/ws?token={token}") as ws:
        ws.send_json({"op": "ping"})
        msg = ws.receive_json()
        assert msg == {"op": "pong"}


def test_ws_unsubscribe_roundtrip(client, db_session):
    _make_user(db_session, email="a@test.com", role="admin")
    token = _login(client, "a@test.com")

    with client.websocket_connect(f"/ws?token={token}") as ws:
        ws.send_json({"op": "subscribe", "topic": "admin:jobs"})
        assert ws.receive_json()["op"] == "subscribed"

        ws.send_json({"op": "unsubscribe", "topic": "admin:jobs"})
        msg = ws.receive_json()
        assert msg == {"op": "unsubscribed", "topic": "admin:jobs"}


def test_ws_bad_op(client, db_session):
    _make_user(db_session, email="a@test.com", role="admin")
    token = _login(client, "a@test.com")

    with client.websocket_connect(f"/ws?token={token}") as ws:
        ws.send_json({"op": "nope"})
        msg = ws.receive_json()
        assert msg["op"] == "error"
        assert msg["code"] == "bad_op"


def test_ws_printer_topic_open_to_authenticated(client, db_session):
    _make_user(db_session, email="op@test.com", role="operator")
    token = _login(client, "op@test.com")
    fake_printer_id = uuid.uuid4()

    with client.websocket_connect(f"/ws?token={token}") as ws:
        ws.send_json({"op": "subscribe", "topic": f"printer:{fake_printer_id}"})
        msg = ws.receive_json()
        assert msg == {"op": "subscribed", "topic": f"printer:{fake_printer_id}"}


def test_ws_stl_forbidden_for_non_owner(client, db_session):
    """Operator cannot subscribe stl:{id} they don't own."""
    from app.models.stl_file import STLFile

    owner = _make_user(db_session, email="owner@test.com", role="operator")
    _make_user(db_session, email="other@test.com", role="operator")
    stl = STLFile(
        id=uuid.uuid4(),
        user_id=owner.id,
        original_filename="x.stl",
        stored_filename=f"{uuid.uuid4()}.stl",
        file_size_bytes=100,
        status="uploaded",
    )
    db_session.add(stl)
    db_session.commit()

    token = _login(client, "other@test.com")
    with client.websocket_connect(f"/ws?token={token}") as ws:
        ws.send_json({"op": "subscribe", "topic": f"stl:{stl.id}"})
        msg = ws.receive_json()
        assert msg["op"] == "error"
        assert msg["code"] == "forbidden"


def test_ws_stl_allowed_for_owner(client, db_session):
    from app.models.stl_file import STLFile

    owner = _make_user(db_session, email="owner@test.com", role="operator")
    stl = STLFile(
        id=uuid.uuid4(),
        user_id=owner.id,
        original_filename="x.stl",
        stored_filename=f"{uuid.uuid4()}.stl",
        file_size_bytes=100,
        status="uploaded",
    )
    db_session.add(stl)
    db_session.commit()

    token = _login(client, "owner@test.com")
    with client.websocket_connect(f"/ws?token={token}") as ws:
        ws.send_json({"op": "subscribe", "topic": f"stl:{stl.id}"})
        msg = ws.receive_json()
        assert msg["op"] == "subscribed"
