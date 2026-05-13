import uuid

from app.core.security import hash_password
from app.models.user import User


def _auth_header(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def test_get_me_returns_profile_and_stats(client, test_user_token, test_user):
    response = client.get("/auth/me", headers=_auth_header(test_user_token))

    assert response.status_code == 200
    body = response.json()
    assert body["id"] == str(test_user.id)
    assert body["email"] == test_user.email
    assert body["full_name"] == test_user.full_name
    assert body["role"] == test_user.role
    assert body["stats"] == {
        "files_uploaded": 0,
        "recommendations_count": 0,
        "jobs_submitted": 0,
    }


def test_update_me_changes_profile(client, test_user_token):
    response = client.patch(
        "/auth/me",
        json={"full_name": "Updated Admin", "email": "updated-admin@test.com"},
        headers=_auth_header(test_user_token),
    )

    assert response.status_code == 200
    body = response.json()
    assert body["full_name"] == "Updated Admin"
    assert body["email"] == "updated-admin@test.com"


def test_update_me_rejects_duplicate_email(client, db_session, test_user_token):
    other_user = User(
        id=uuid.uuid4(),
        email="other@test.com",
        full_name="Other User",
        password=hash_password("password123"),
        role="operator",
        is_active=True,
    )
    db_session.add(other_user)
    db_session.commit()

    response = client.patch(
        "/auth/me",
        json={"email": "other@test.com"},
        headers=_auth_header(test_user_token),
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "Email already in use"
