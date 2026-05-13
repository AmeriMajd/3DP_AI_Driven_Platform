import uuid

from app.core.security import create_access_token, hash_password
from app.models.user import User


def _auth_header(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def test_require_role_uses_database_role_not_token_claim(client, db_session):
    operator = User(
        id=uuid.uuid4(),
        email="operator@test.com",
        full_name="Operator User",
        password=hash_password("password123"),
        role="operator",
        is_active=True,
    )
    db_session.add(operator)
    db_session.commit()

    forged_admin_token = create_access_token(
        {"sub": str(operator.id), "role": "admin"}
    )

    response = client.post(
        "/admin/invitations",
        json={"email": "new-user@test.com", "role": "operator"},
        headers=_auth_header(forged_admin_token),
    )

    assert response.status_code == 403
    assert response.json()["detail"] == "Admin access required"


def test_get_current_user_rejects_disabled_user(client, db_session, test_user):
    login_response = client.post(
        "/auth/login",
        json={"email": test_user.email, "password": "password123"},
    )
    access_token = login_response.json()["access_token"]

    test_user.is_active = False
    db_session.commit()

    response = client.get("/auth/me", headers=_auth_header(access_token))

    assert response.status_code == 403
    assert response.json()["detail"] == "Account is disabled"


def test_require_role_rejects_disabled_user(client, db_session, test_user):
    login_response = client.post(
        "/auth/login",
        json={"email": test_user.email, "password": "password123"},
    )
    access_token = login_response.json()["access_token"]

    test_user.is_active = False
    db_session.commit()

    response = client.post(
        "/admin/invitations",
        json={"email": "new-user@test.com", "role": "operator"},
        headers=_auth_header(access_token),
    )

    assert response.status_code == 403
    assert response.json()["detail"] == "Account is disabled"
