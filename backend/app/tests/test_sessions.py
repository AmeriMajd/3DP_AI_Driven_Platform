def _auth_header(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _login(client, email: str = "admin@test.com") -> dict:
    response = client.post(
        "/auth/login",
        json={"email": email, "password": "password123"},
    )
    assert response.status_code == 200
    return response.json()


def test_refresh_returns_new_access_token(client, test_user):
    tokens = _login(client, test_user.email)

    response = client.post(
        "/auth/refresh",
        json={"refresh_token": tokens["refresh_token"]},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["access_token"]
    assert body["token_type"] == "bearer"


def test_logout_revokes_refresh_token(client, test_user):
    tokens = _login(client, test_user.email)

    logout_response = client.post(
        "/auth/logout",
        json={"refresh_token": tokens["refresh_token"]},
        headers=_auth_header(tokens["access_token"]),
    )
    refresh_response = client.post(
        "/auth/refresh",
        json={"refresh_token": tokens["refresh_token"]},
    )

    assert logout_response.status_code == 200
    assert refresh_response.status_code == 401
    assert refresh_response.json()["detail"] == "Invalid or expired refresh token"


def test_logout_is_idempotent(client, test_user):
    tokens = _login(client, test_user.email)

    first_response = client.post(
        "/auth/logout",
        json={"refresh_token": tokens["refresh_token"]},
        headers=_auth_header(tokens["access_token"]),
    )
    second_response = client.post(
        "/auth/logout",
        json={"refresh_token": tokens["refresh_token"]},
        headers=_auth_header(tokens["access_token"]),
    )

    assert first_response.status_code == 200
    assert second_response.status_code == 200


def test_revoke_all_sessions_invalidates_refresh_tokens(client, test_user):
    first_tokens = _login(client, test_user.email)
    second_tokens = _login(client, test_user.email)

    revoke_response = client.delete(
        "/auth/me/sessions",
        headers=_auth_header(first_tokens["access_token"]),
    )
    first_refresh_response = client.post(
        "/auth/refresh",
        json={"refresh_token": first_tokens["refresh_token"]},
    )
    second_refresh_response = client.post(
        "/auth/refresh",
        json={"refresh_token": second_tokens["refresh_token"]},
    )

    assert revoke_response.status_code == 200
    assert first_refresh_response.status_code == 401
    assert second_refresh_response.status_code == 401
