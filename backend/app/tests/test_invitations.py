from datetime import datetime, timedelta

from app.models.invitation import Invitation
from app.models.user import User


def _auth_header(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def test_admin_can_create_invitation_and_validate_via_db_token(
    client, db_session, test_user_token
):
    create_resp = client.post(
        "/admin/invitations",
        json={"email": "operator@test.com", "role": "operator"},
        headers=_auth_header(test_user_token),
    )

    assert create_resp.status_code == 201
    created = create_resp.json()
    assert created["email"] == "operator@test.com"
    assert created["role"] == "operator"
    assert created["email_sent"] is True
    assert "id" in created
    # The link and raw token are no longer exposed in the response.
    assert "link" not in created
    assert "token" not in created

    invitation = (
        db_session.query(Invitation)
        .filter(Invitation.email == "operator@test.com")
        .first()
    )
    assert invitation is not None

    validate_resp = client.get(
        "/invitations/validate",
        params={"token": invitation.token},
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


def test_resend_invitation_rotates_token_and_extends_expiry(
    client, db_session, test_user, test_user_token
):
    invitation = Invitation(
        email="resend@test.com",
        role="operator",
        token="old-token",
        created_by=test_user.id,
        # Simulate an invitation issued >1h ago so the rate-limit allows resend.
        expires_at=datetime.utcnow() + timedelta(hours=20),
    )
    db_session.add(invitation)
    db_session.commit()
    original_expiry = invitation.expires_at

    resp = client.post(
        f"/admin/invitations/{invitation.id}/resend",
        headers=_auth_header(test_user_token),
    )

    assert resp.status_code == 200
    body = resp.json()
    assert body["email_sent"] is True

    db_session.refresh(invitation)
    assert invitation.token != "old-token"
    assert invitation.expires_at > original_expiry


def test_resend_rejects_used_invitation(
    client, db_session, test_user, test_user_token
):
    invitation = Invitation(
        email="already-used@test.com",
        role="operator",
        token="some-token",
        created_by=test_user.id,
        expires_at=datetime.utcnow() + timedelta(hours=20),
        used=True,
    )
    db_session.add(invitation)
    db_session.commit()

    resp = client.post(
        f"/admin/invitations/{invitation.id}/resend",
        headers=_auth_header(test_user_token),
    )

    assert resp.status_code == 400
    assert resp.json()["detail"] == "Invitation already used"


def test_resend_rate_limited_within_one_hour(
    client, db_session, test_user, test_user_token
):
    # Fresh invitation (expires_at - now > 47h) → resend should be blocked.
    invitation = Invitation(
        email="recent@test.com",
        role="operator",
        token="recent-token",
        created_by=test_user.id,
        expires_at=datetime.utcnow() + timedelta(hours=47, minutes=59),
    )
    db_session.add(invitation)
    db_session.commit()

    resp = client.post(
        f"/admin/invitations/{invitation.id}/resend",
        headers=_auth_header(test_user_token),
    )

    assert resp.status_code == 429
    assert "less than an hour ago" in resp.json()["detail"]


def test_resend_404_for_unknown_id(client, test_user_token):
    import uuid as uuid_lib

    resp = client.post(
        f"/admin/invitations/{uuid_lib.uuid4()}/resend",
        headers=_auth_header(test_user_token),
    )

    assert resp.status_code == 404
