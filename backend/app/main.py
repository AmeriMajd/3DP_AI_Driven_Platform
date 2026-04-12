from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text
from app.core.database import engine, Base

# ── Import ALL models before create_all ───────────────────────────────────────
import app.models.user
import app.models.invitation
import app.models.refresh_token
import app.models.password_reset_token
from app.models.stl_file import STLFile

# ── Import routers ─────────────────────────────────────────────────────────────
from app.routers import auth, admin, invitations
from app.routers import refresh
from app.routers import password_reset
from app.routers import logout
from app.routers.stl import router as stl_router
from app.services import stl_service

# ── Create all tables ──────────────────────────────────────────────────────────
Base.metadata.create_all(bind=engine)


def _sync_stl_files_schema() -> None:
    """
    Lightweight schema backfill for existing databases.
    Ensures newly added STL analysis columns exist without manual DB reset.
    """
    statements = [
        # Pre-existing columns
        "ALTER TABLE stl_files ADD COLUMN IF NOT EXISTS volume_cm3 DOUBLE PRECISION",
        "ALTER TABLE stl_files ADD COLUMN IF NOT EXISTS surface_area_cm2 DOUBLE PRECISION",
        "ALTER TABLE stl_files ADD COLUMN IF NOT EXISTS bbox_x_mm DOUBLE PRECISION",
        "ALTER TABLE stl_files ADD COLUMN IF NOT EXISTS bbox_y_mm DOUBLE PRECISION",
        "ALTER TABLE stl_files ADD COLUMN IF NOT EXISTS bbox_z_mm DOUBLE PRECISION",
        "ALTER TABLE stl_files ADD COLUMN IF NOT EXISTS triangle_count INTEGER",
        "ALTER TABLE stl_files ADD COLUMN IF NOT EXISTS has_overhangs BOOLEAN",
        "ALTER TABLE stl_files ADD COLUMN IF NOT EXISTS has_thin_walls BOOLEAN",
        "ALTER TABLE stl_files ADD COLUMN IF NOT EXISTS glb_filename VARCHAR",
        # Sprint 2B — geometry feature columns
        "ALTER TABLE stl_files ADD COLUMN IF NOT EXISTS overhang_ratio DOUBLE PRECISION",
        "ALTER TABLE stl_files ADD COLUMN IF NOT EXISTS max_overhang_angle DOUBLE PRECISION",
        "ALTER TABLE stl_files ADD COLUMN IF NOT EXISTS min_wall_thickness_mm DOUBLE PRECISION",
        "ALTER TABLE stl_files ADD COLUMN IF NOT EXISTS avg_wall_thickness_mm DOUBLE PRECISION",
        "ALTER TABLE stl_files ADD COLUMN IF NOT EXISTS complexity_index DOUBLE PRECISION",
        "ALTER TABLE stl_files ADD COLUMN IF NOT EXISTS aspect_ratio DOUBLE PRECISION",
        "ALTER TABLE stl_files ADD COLUMN IF NOT EXISTS is_watertight BOOLEAN",
        "ALTER TABLE stl_files ADD COLUMN IF NOT EXISTS shell_count INTEGER",
        "ALTER TABLE stl_files ADD COLUMN IF NOT EXISTS com_offset_ratio DOUBLE PRECISION",
        "ALTER TABLE stl_files ADD COLUMN IF NOT EXISTS flat_base_area_mm2 DOUBLE PRECISION",
        "ALTER TABLE stl_files ADD COLUMN IF NOT EXISTS face_normal_histogram JSONB",
        # Sprint 2B — orientation result columns
        "ALTER TABLE stl_files ADD COLUMN IF NOT EXISTS best_orientation_1 JSONB",
        "ALTER TABLE stl_files ADD COLUMN IF NOT EXISTS best_orientation_2 JSONB",
        "ALTER TABLE stl_files ADD COLUMN IF NOT EXISTS best_orientation_3 JSONB",
        "ALTER TABLE stl_files ADD COLUMN IF NOT EXISTS best_orientation_score DOUBLE PRECISION",
    ]
    with engine.begin() as connection:
        for statement in statements:
            connection.execute(text(statement))


_sync_stl_files_schema()

app = FastAPI(
    title="3DP Intelligence Platform",
    version="1.0.0",
    description="AI-Driven Additive Manufacturing Platform API"
)

# ── CORS ───────────────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ────────────────────────────────────────────────────────────────────
app.include_router(auth.router)
app.include_router(refresh.router)
app.include_router(admin.router)
app.include_router(invitations.router)
app.include_router(password_reset.router)
app.include_router(logout.router)
app.include_router(stl_router)


@app.on_event("startup")
def recover_stl_jobs() -> None:
    stl_service.recover_pending_files()

@app.get("/", tags=["Health"])
def root():
    return {"message": "3DP API is running"}

@app.get("/health", tags=["Health"])
def health():
    return {"status": "ok"}

