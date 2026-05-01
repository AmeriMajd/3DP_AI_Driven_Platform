"""
Shared fixtures for backend/tests/.

Engine patching mirrors backend/app/tests/conftest.py — must happen at module
level, before any app import, to prevent a production-PostgreSQL connection.
"""

import uuid
import pytest
from sqlalchemy import create_engine, pool
from sqlalchemy.orm import sessionmaker
from fastapi.testclient import TestClient

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
