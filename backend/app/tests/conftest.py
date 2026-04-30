"""
Shared pytest fixtures for integration tests.

Key design decisions:
- SQLite in-memory with StaticPool replaces PostgreSQL (no external DB needed).
- DB engine is patched BEFORE any app module is imported to avoid a
  production-PostgreSQL connection attempt at import time.
- upload dirs are redirected to a temp path per test (see patch_upload_dirs).
- The background analysis pipeline is suppressed in upload tests
  (see patch_background_pipeline in test_stl_upload_flow.py).
"""

import uuid
from sqlalchemy import create_engine, pool
from sqlalchemy.orm import sessionmaker
from fastapi.testclient import TestClient
import pytest

# ── 1. Create the test engine FIRST ──────────────────────────────────────────
engine = create_engine(
    "sqlite:///:memory:",
    connect_args={"check_same_thread": False},
    poolclass=pool.StaticPool,
    echo=False,
)

# ── 2. Patch db_module BEFORE any app import ──────────────────────────────────
import app.core.database as db_module
db_module.engine = engine
db_module.SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# ── 3. Register all models, then import the app ───────────────────────────────
import app.models.user
import app.models.invitation
import app.models.refresh_token
import app.models.password_reset_token
import app.models.stl_file
import app.models.printer
import app.models.print_job    
import app.models.recommendation  

from app.main import app
from app.core.database import get_db, Base
from app.models.user import User
from app.core.security import hash_password

Base.metadata.create_all(bind=engine)


# ── Helpers ───────────────────────────────────────────────────────────────────

def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


# ── Fixtures ──────────────────────────────────────────────────────────────────

@pytest.fixture(scope="function")
def db_session():
    Base.metadata.create_all(bind=engine)
    session = TestingSessionLocal()
    yield session
    session.close()
    Base.metadata.drop_all(bind=engine)


@pytest.fixture(scope="function")
def client(db_session):
    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)
    app.dependency_overrides.clear()


@pytest.fixture
def test_user(db_session):
    user = User(
        id=uuid.uuid4(),
        email="admin@test.com",
        full_name="Test Admin",
        password=hash_password("password123"),
        role="admin",
        is_active=True,
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


@pytest.fixture
def test_user_token(client, test_user):
    response = client.post(
        "/auth/login",
        json={"email": test_user.email, "password": "password123"},
    )
    assert response.status_code == 200
    return response.json()["access_token"]


@pytest.fixture
def sample_stl_file_bytes():
    """Minimal valid binary STL — single triangle."""
    header         = b"Binary STL test file" + b"\x00" * 60   # 80 bytes
    triangle_count = b"\x01\x00\x00\x00"                      # 1 triangle
    normal         = b"\x00\x00\x00\x00\x00\x00\x80\x3f\x00\x00\x00\x00"
    v1             = b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
    v2             = b"\x00\x00\x80\x3f\x00\x00\x00\x00\x00\x00\x00\x00"
    v3             = b"\x00\x00\x00\x00\x00\x00\x80\x3f\x00\x00\x00\x00"
    attr           = b"\x00\x00"
    return header + triangle_count + normal + v1 + v2 + v3 + attr
