from app.core.config import settings
from app.core.security import verify_password
from app.models.user import User


def _auth_header(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def test_admin_status_and_signup(client):
    status_before = client.get("/auth/admin/status")
    assert status_before.status_code == 200
    assert status_before.json() == {"initialized": False}

    signup_response = client.post(
        "/auth/admin/signup",
        json={
            "full_name": "First Admin",
            "email": "first-admin@test.com",
            "password": "password123",
            "admin_secret_key": settings.ADMIN_SIGNUP_KEY,
        },
    )
    status_after = client.get("/auth/admin/status")

    assert signup_response.status_code == 201
    assert signup_response.json()["role"] == "admin"
    assert status_after.json() == {"initialized": True}


def test_admin_signup_rejects_invalid_secret(client):
    response = client.post(
        "/auth/admin/signup",
        json={
            "full_name": "First Admin",
            "email": "first-admin@test.com",
            "password": "password123",
            "admin_secret_key": "wrong-secret",
        },
    )

    assert response.status_code == 403
    assert response.json()["detail"] == "Invalid admin secret key"


def test_login_rejects_invalid_password(client, test_user):
    response = client.post(
        "/auth/login",
        json={"email": test_user.email, "password": "wrong-password"},
    )

    assert response.status_code == 401
    assert response.json()["detail"] == "Invalid credentials"


def test_login_rejects_disabled_user(client, db_session, test_user):
    test_user.is_active = False
    db_session.commit()

    response = client.post(
        "/auth/login",
        json={"email": test_user.email, "password": "password123"},
    )

    assert response.status_code == 403
    assert response.json()["detail"] == "Account is disabled"


def test_change_password_updates_hash(client, db_session, test_user):
    login_response = client.post(
        "/auth/login",
        json={"email": test_user.email, "password": "password123"},
    )
    access_token = login_response.json()["access_token"]

    response = client.patch(
        "/auth/me/password",
        json={
            "current_password": "password123",
            "new_password": "new-password123",
        },
        headers=_auth_header(access_token),
    )

    db_session.refresh(test_user)
    assert response.status_code == 200
    assert verify_password("new-password123", test_user.password)


def test_change_password_rejects_wrong_current_password(client, test_user):
    login_response = client.post(
        "/auth/login",
        json={"email": test_user.email, "password": "password123"},
    )
    access_token = login_response.json()["access_token"]

    response = client.patch(
        "/auth/me/password",
        json={
            "current_password": "bad-password",
            "new_password": "new-password123",
        },
        headers=_auth_header(access_token),
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "Current password is incorrect"


def test_register_creates_user_from_invitation_service_flow(
    client,
    db_session,
    test_user_token,
):
    invitation_response = client.post(
        "/admin/invitations",
        json={"email": "invited-operator@test.com", "role": "operator"},
        headers=_auth_header(test_user_token),
    )
    assert invitation_response.status_code == 201
    from app.models.invitation import Invitation
    invitation = (
        db_session.query(Invitation)
        .filter(Invitation.email == "invited-operator@test.com")
        .first()
    )
    token = invitation.token

    register_response = client.post(
        "/auth/register",
        json={
            "token": token,
            "full_name": "Invited Operator",
            "password": "password123",
        },
    )
    user = (
        db_session.query(User)
        .filter(User.email == "invited-operator@test.com")
        .first()
    )

    assert register_response.status_code == 201
    assert register_response.json()["email"] == "invited-operator@test.com"
    assert register_response.json()["role"] == "operator"
    assert user is not None
