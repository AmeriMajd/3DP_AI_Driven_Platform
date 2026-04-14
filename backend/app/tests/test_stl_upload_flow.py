"""
End-to-end integration tests for the STL upload → geometry → orientation pipeline.

Fixtures (autouse):
- patch_upload_dirs  : redirects UPLOAD_DIR / GLB_DIR to a temp directory.
- patch_background_pipeline : suppresses the async analysis task.
"""
import io
import uuid
import pytest
from unittest.mock import patch
from fastapi import status


@pytest.fixture(autouse=True)
def patch_upload_dirs(tmp_path):
    stl_dir = tmp_path / "stl"
    glb_dir = tmp_path / "glb"
    stl_dir.mkdir()
    glb_dir.mkdir()
    with patch("app.services.stl_service.UPLOAD_DIR", stl_dir), \
         patch("app.services.stl_service.GLB_DIR", glb_dir):
        yield


@pytest.fixture(autouse=True)
def patch_background_pipeline():
    with patch("app.services.stl_service.run_analysis_pipeline"):
        yield


# ── Upload ────────────────────────────────────────────────────────────────────

def test_upload_returns_201(client, test_user_token, sample_stl_file_bytes):
    resp = client.post(
        "/stl/upload",
        files={"file": ("test.stl", io.BytesIO(sample_stl_file_bytes), "application/octet-stream")},
        headers={"Authorization": f"Bearer {test_user_token}"},
    )
    assert resp.status_code == status.HTTP_201_CREATED
    data = resp.json()
    assert "id" in data
    assert data["original_filename"] == "test.stl"
    assert data["status"] in {"uploaded", "analyzing"}


def test_upload_tracks_file_size(client, test_user_token, sample_stl_file_bytes):
    resp = client.post(
        "/stl/upload",
        files={"file": ("test.stl", io.BytesIO(sample_stl_file_bytes), "application/octet-stream")},
        headers={"Authorization": f"Bearer {test_user_token}"},
    )
    assert resp.status_code == status.HTTP_201_CREATED
    assert resp.json()["file_size_bytes"] == len(sample_stl_file_bytes)


def test_upload_requires_auth(client, sample_stl_file_bytes):
    resp = client.post(
        "/stl/upload",
        files={"file": ("test.stl", io.BytesIO(sample_stl_file_bytes), "application/octet-stream")},
    )
    assert resp.status_code in (status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN)


# ── Retrieve ──────────────────────────────────────────────────────────────────

def test_get_file_after_upload(client, test_user_token, sample_stl_file_bytes):
    file_id = client.post(
        "/stl/upload",
        files={"file": ("cube.stl", io.BytesIO(sample_stl_file_bytes), "application/octet-stream")},
        headers={"Authorization": f"Bearer {test_user_token}"},
    ).json()["id"]

    resp = client.get(f"/stl/{file_id}", headers={"Authorization": f"Bearer {test_user_token}"})
    assert resp.status_code == status.HTTP_200_OK
    assert resp.json()["id"] == file_id


def test_list_files(client, test_user_token, sample_stl_file_bytes):
    for i in range(2):
        client.post(
            "/stl/upload",
            files={"file": (f"file{i}.stl", io.BytesIO(sample_stl_file_bytes), "application/octet-stream")},
            headers={"Authorization": f"Bearer {test_user_token}"},
        )

    resp = client.get("/stl/", headers={"Authorization": f"Bearer {test_user_token}"})
    assert resp.status_code == status.HTTP_200_OK
    files = resp.json().get("files", resp.json())
    assert len(files) >= 2


# ── Delete ────────────────────────────────────────────────────────────────────

def test_delete_file(client, test_user_token, sample_stl_file_bytes):
    file_id = client.post(
        "/stl/upload",
        files={"file": ("del.stl", io.BytesIO(sample_stl_file_bytes), "application/octet-stream")},
        headers={"Authorization": f"Bearer {test_user_token}"},
    ).json()["id"]

    assert client.delete(
        f"/stl/{file_id}", headers={"Authorization": f"Bearer {test_user_token}"}
    ).status_code == status.HTTP_204_NO_CONTENT

    assert client.get(
        f"/stl/{file_id}", headers={"Authorization": f"Bearer {test_user_token}"}
    ).status_code == status.HTTP_404_NOT_FOUND


# ── Isolation ─────────────────────────────────────────────────────────────────

def test_files_are_user_scoped(client, test_user_token, db_session, sample_stl_file_bytes):
    """Files uploaded by user A must not appear in user B's listing."""
    from app.models.user import User
    from app.core.security import hash_password

    client.post(
        "/stl/upload",
        files={"file": ("a.stl", io.BytesIO(sample_stl_file_bytes), "application/octet-stream")},
        headers={"Authorization": f"Bearer {test_user_token}"},
    )

    user_b = User(
        id=uuid.uuid4(),
        email="user_b@test.com",
        full_name="User B",
        password=hash_password("password456"),
        role="operator",
        is_active=True,
    )
    db_session.add(user_b)
    db_session.commit()

    token_b = client.post(
        "/auth/login",
        json={"email": "user_b@test.com", "password": "password456"},
    ).json()["access_token"]

    resp = client.get("/stl/", headers={"Authorization": f"Bearer {token_b}"})
    files = resp.json().get("files", resp.json())
    assert len(files) == 0
