from datetime import datetime, timedelta

from app.models.invitation import Invitation
from app.models.user import User


def _auth_header(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def test_admin_can_create_and_validate_invitation(client, test_user_token):
    create_resp = client.post(
        "/admin/invitations",
        json={"email": "operator@test.com", "role": "operator"},
        headers=_auth_header(test_user_token),
    )

    assert create_resp.status_code == 201
    created = create_resp.json()
    assert created["email"] == "operator@test.com"
    assert created["role"] == "operator"
    assert "/register?token=" in created["link"]

    validate_resp = client.get(
        "/invitations/validate",
        params={"token": created["token"]},
    )

    assert validate_resp.status_code == 200
    validated = validate_resp.json()
    assert validated["email"] == "operator@test.com"
    assert validated["role"] == "operator"


def test_register_consumes_invitation_and_reuse_fails(client, db_session, test_user):
    invitation = Invitation(
        email="new-operator@test.com",
        role="operator",
        token="valid-register-token",
        created_by=test_user.id,
        expires_at=datetime.utcnow() + timedelta(hours=1),
    )
    db_session.add(invitation)
    db_session.commit()

    register_resp = client.post(
        "/auth/register",
        json={
            "token": "valid-register-token",
            "full_name": "New Operator",
            "password": "password123",
        },
    )

    assert register_resp.status_code == 201
    registered = register_resp.json()
    assert registered["email"] == "new-operator@test.com"
    assert registered["role"] == "operator"

    db_session.refresh(invitation)
    assert invitation.used is True
    assert (
        db_session.query(User)
        .filter(User.email == "new-operator@test.com")
        .first()
        is not None
    )

    reuse_resp = client.post(
        "/auth/register",
        json={
            "token": "valid-register-token",
            "full_name": "Other Operator",
            "password": "password123",
        },
    )

    assert reuse_resp.status_code == 400
    assert reuse_resp.json()["detail"] == "Invalid or expired invitation"


def test_validate_rejects_expired_and_used_invitations(client, db_session, test_user):
    expired = Invitation(
        email="expired@test.com",
        role="operator",
        token="expired-token",
        created_by=test_user.id,
        expires_at=datetime.utcnow() - timedelta(minutes=1),
    )
    used = Invitation(
        email="used@test.com",
        role="operator",
        token="used-token",
        created_by=test_user.id,
        expires_at=datetime.utcnow() + timedelta(hours=1),
        used=True,
    )
    db_session.add_all([expired, used])
    db_session.commit()

    expired_resp = client.get(
        "/invitations/validate",
        params={"token": "expired-token"},
    )
    used_resp = client.get(
        "/invitations/validate",
        params={"token": "used-token"},
    )

    assert expired_resp.status_code == 400
    assert used_resp.status_code == 400
    assert expired_resp.json()["detail"] == "Invalid or expired invitation"
    assert used_resp.json()["detail"] == "Invalid or expired invitation"
