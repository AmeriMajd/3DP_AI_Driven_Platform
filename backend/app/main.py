from fastapi import FastAPI
from app.core.database import engine, Base

# ── CRITICAL: Import models before create_all ─────────────────────────────────
# These imports register the models with SQLAlchemy's Base.
# Without them, create_all() below would create NO tables.
# The import triggers the model file to execute, which calls Base's
# class registration mechanism under the hood.
import app.models.user          # registers User model → users table
import app.models.invitation     # registers Invitation model → invitations table

# ── Import routers ─────────────────────────────────────────────────────────────
from app.routers import auth, admin, invitations

# ── Create tables ──────────────────────────────────────────────────────────────
# This runs once on startup.
# It reads all registered models and creates their tables in PostgreSQL
# IF they don't already exist. It NEVER drops or modifies existing tables.
# Safe to run on every restart.
Base.metadata.create_all(bind=engine)

# ── Create FastAPI app ─────────────────────────────────────────────────────────
app = FastAPI(
    title="3DP Intelligence Platform",
    version="1.0.0",
    description="AI-Driven Additive Manufacturing Platform API"
)

# ── Register routers ───────────────────────────────────────────────────────────
# Each router adds its group of endpoints to the app.
# include_router is how FastAPI knows about them.
app.include_router(auth.router)           # /auth/admin/signup, /auth/register
app.include_router(admin.router)          # /admin/invitations
app.include_router(invitations.router)    # /invitations/validate


# ── Health check endpoints ─────────────────────────────────────────────────────

@app.get("/", tags=["Health"])
def root():
    return {"message": "3DP API is running"}

@app.get("/health", tags=["Health"])
def health():
    return {"status": "ok"}
@app.get("/dev/token", tags=["Dev"])
def get_dev_token():
    from app.core.security import create_access_token
    token = create_access_token({"sub": "dev-admin", "role": "admin"})
    return {"token": token, "usage": f"Bearer {token}"}