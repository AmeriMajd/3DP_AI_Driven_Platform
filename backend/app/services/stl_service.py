import uuid
import logging
from pathlib import Path
from typing import Any
from fastapi import BackgroundTasks
from fastapi import UploadFile, HTTPException
from sqlalchemy.orm import Session

from app.core.database import SessionLocal
from app.models.stl_file import STLFile
import app.models.user  # Ensure FK target table metadata is registered.
from app.services.geometry_service import (
    convert_to_glb,
    extract_features_from_mesh,
    load_mesh,
)
from app.services import orientation_service

logger = logging.getLogger(__name__)

UPLOAD_DIR = Path("/app/uploads/stl")
GLB_DIR = Path("/app/uploads/glb")
MAX_FILE_SIZE = 50 * 1024 * 1024  # 50 MB
ALLOWED_EXTENSIONS = {".stl", ".3mf"}
VALID_STATUSES = {"uploaded", "analyzing", "ready", "error"}


def _get_extension(filename: str) -> str:
    return Path(filename).suffix.lower()


def _safe_float(value: Any) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _safe_int(value: Any) -> int | None:
    if value is None:
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _safe_bool(value: Any) -> bool | None:
    if value is None:
        return None
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        lowered = value.strip().lower()
        if lowered in {"true", "yes", "1"}:
            return True
        if lowered in {"false", "no", "0"}:
            return False
    return None


async def save_stl_file(file: UploadFile, user_id: uuid.UUID, db: Session, background_tasks: BackgroundTasks,) -> STLFile:
    """
    Validate, write to disk, and persist metadata to DB.
    Raises HTTPException for all validation failures.
    """
    # 1. Validate file was provided
    if not file or not file.filename:
        raise HTTPException(status_code=400, detail="No file provided.")

    # 2. Validate extension
    ext = _get_extension(file.filename)
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=422,
            detail=f"Unsupported file type '{ext}'. Only .stl and .3mf are allowed.",
        )

    # 3. Read contents and enforce size + empty-file rules
    contents = await file.read()
    if len(contents) == 0:
        raise HTTPException(status_code=400, detail="Uploaded file is empty.")

    if len(contents) > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=413,
            detail="File exceeds the 50MB size limit.",
        )

    # 4. Generate stable UUID for both the DB row and the on-disk filename
    file_id = uuid.uuid4()
    stored_filename = f"{file_id}{ext}"

    # 5. Ensure upload directory exists and write file
    UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
    disk_path = UPLOAD_DIR / stored_filename

    try:
        disk_path.write_bytes(contents)
    except OSError as exc:
        raise HTTPException(status_code=500, detail="Failed to write file to disk.") from exc

    # 6. Persist metadata
    stl_record = STLFile(
        id=file_id,
        user_id=user_id,
        original_filename=file.filename,
        stored_filename=stored_filename,
        file_size_bytes=len(contents),
        status="uploaded",
    )

    try:
        db.add(stl_record)
        db.commit()
        db.refresh(stl_record)
    except Exception as exc:
        disk_path.unlink(missing_ok=True)  # roll back disk write
        db.rollback()
        raise HTTPException(status_code=500, detail="Database error while saving file.") from exc

    background_tasks.add_task(
        run_analysis_pipeline,
        stl_id=stl_record.id,
        file_path=str(disk_path),
    )
    return _with_glb_url(stl_record)


def list_stl_files(user_id: uuid.UUID, db: Session) -> list[STLFile]:
    """Return all files for the current user, most recent first."""
    records = (
        db.query(STLFile)
        .filter(STLFile.user_id == user_id)
        .order_by(STLFile.created_at.desc())
        .all()
    )
    return [_with_glb_url(record) for record in records]


def get_stl_file(stl_id: uuid.UUID, user_id: uuid.UUID, db: Session) -> STLFile:
    """
    Return one file belonging to the current user.
    404 whether the file doesn't exist OR belongs to another user —
    never expose that another user's file exists.
    """
    record = (
        db.query(STLFile)
        .filter(STLFile.id == stl_id, STLFile.user_id == user_id)
        .first()
    )
    if not record:
        raise HTTPException(status_code=404, detail="File not found.")
    return _with_glb_url(record)


def update_stl_status(
    stl_id: uuid.UUID, user_id: uuid.UUID, new_status: str, db: Session
) -> STLFile:
    """
    Update the processing status of a file.
    Only the owner can update their file's status.
    """
    if new_status not in VALID_STATUSES:
        raise HTTPException(
            status_code=422,
            detail=f"Invalid status '{new_status}'. Must be one of {VALID_STATUSES}.",
        )

    record = get_stl_file(stl_id, user_id, db)  # raises 404 if not owned
    record.status = new_status

    try:
        db.commit()
        db.refresh(record)
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=500, detail="Database error while updating status.") from exc

    return _with_glb_url(record)


def delete_stl_file(stl_id: uuid.UUID, user_id: uuid.UUID, db: Session) -> None:
    record = get_stl_file(stl_id, user_id, db)

    # Delete STL from disk
    stl_path = UPLOAD_DIR / record.stored_filename
    stl_path.unlink(missing_ok=True)

    # ← ADD: also delete the GLB if it exists
    if record.glb_filename:
        glb_path = GLB_DIR / record.glb_filename
        glb_path.unlink(missing_ok=True)

    try:
        db.delete(record)
        db.commit()
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=500, detail="Database error while deleting file.") from exc


def get_glb_path(stl_id: uuid.UUID, user_id: uuid.UUID, db: Session) -> Path:
    """
    Return GLB path for an owned file.
    Raises 404 if file does not exist, is not owned, or GLB is not ready.
    """
    record = get_stl_file(stl_id=stl_id, user_id=user_id, db=db)
    if record.glb_filename:
        glb_path = GLB_DIR / record.glb_filename
        if glb_path.exists() and glb_path.is_file():
            return glb_path

    # Self-heal inconsistent rows where DB says the file exists but GLB is missing.
    source_path = UPLOAD_DIR / record.stored_filename
    if not source_path.exists() or not source_path.is_file():
        raise HTTPException(status_code=404, detail="GLB not available yet.")

    try:
        regenerated_glb = convert_to_glb(input_path=str(source_path), uuid=str(record.id))
    except Exception as exc:
        logger.exception("Failed to regenerate missing GLB", extra={"stl_id": str(stl_id)})
        raise HTTPException(status_code=404, detail="GLB not available yet.") from exc

    record.glb_filename = Path(regenerated_glb).name
    if record.status != "ready":
        record.status = "ready"

    try:
        db.commit()
        db.refresh(record)
    except Exception:
        db.rollback()

    return Path(regenerated_glb)


def queue_reprocess(
    stl_id: uuid.UUID,
    user_id: uuid.UUID,
    db: Session,
    background_tasks: BackgroundTasks,
) -> STLFile:
    """Queue analysis again for an owned file and reset stale derived fields."""
    record = get_stl_file(stl_id=stl_id, user_id=user_id, db=db)
    source_path = UPLOAD_DIR / record.stored_filename
    if not source_path.exists() or not source_path.is_file():
        raise HTTPException(status_code=404, detail="Source STL/3MF file not found on server.")

    record.status = "uploaded"
    record.volume_cm3 = None
    record.surface_area_cm2 = None
    record.bbox_x_mm = None
    record.bbox_y_mm = None
    record.bbox_z_mm = None
    record.triangle_count = None
    record.has_overhangs = None
    record.has_thin_walls = None
    record.glb_filename = None
    # Sprint 2B fields
    record.overhang_ratio = None
    record.max_overhang_angle = None
    record.min_wall_thickness_mm = None
    record.avg_wall_thickness_mm = None
    record.complexity_index = None
    record.aspect_ratio = None
    record.is_watertight = None
    record.shell_count = None
    record.com_offset_ratio = None
    record.flat_base_area_mm2 = None
    record.face_normal_histogram = None
    record.best_orientation_1 = None
    record.best_orientation_2 = None
    record.best_orientation_3 = None
    record.best_orientation_score = None

    try:
        db.commit()
        db.refresh(record)
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=500, detail="Failed to queue reprocessing.") from exc

    background_tasks.add_task(
        run_analysis_pipeline,
        stl_id=record.id,
        file_path=str(source_path),
    )
    return _with_glb_url(record)


def get_orientations(stl_id: uuid.UUID, user_id: uuid.UUID, db: Session) -> list:
    """
    Return the top 3 pre-computed orientations for an owned file.
    - 404 if file not found or not owned by current user.
    - 400 if geometry analysis hasn't completed yet.
    """
    record = get_stl_file(stl_id, user_id, db)  # raises 404 if not owned

    if record.status != "ready":
        raise HTTPException(
            status_code=400,
            detail="Geometry analysis still in progress. Please try again shortly.",
        )

    orientations = [
        record.best_orientation_1,
        record.best_orientation_2,
        record.best_orientation_3,
    ]
    # Filter out any None slots (e.g. if mesh had fewer than 3 candidates)
    return [o for o in orientations if o is not None]


def run_analysis_pipeline(stl_id: uuid.UUID, file_path: str) -> None:
    """
    Background pipeline (runs after upload):
      1. Load mesh once from disk.
      2. Extract all geometry features → write to DB.
      3. Run orientation optimization → write best_orientation_1/2/3 + score to DB.
      4. Convert to GLB for 3D preview (reuses the already-loaded mesh).
      5. Set status = "ready".
    On any failure, set status = "error".
    """
    db = SessionLocal()
    try:
        record = db.query(STLFile).filter(STLFile.id == stl_id).first()
        if not record:
            return

        record.status = "analyzing"
        db.commit()

        # ── Step 1: load mesh once ────────────────────────────────────────────
        mesh = load_mesh(Path(file_path))

        # ── Step 2: geometry extraction ───────────────────────────────────────
        features = extract_features_from_mesh(mesh)

        record.volume_cm3 = _safe_float(features.get("volume_cm3"))
        record.surface_area_cm2 = _safe_float(features.get("surface_area_cm2"))
        record.bbox_x_mm = _safe_float(features.get("bbox_x_mm"))
        record.bbox_y_mm = _safe_float(features.get("bbox_y_mm"))
        record.bbox_z_mm = _safe_float(features.get("bbox_z_mm"))
        record.triangle_count = _safe_int(features.get("triangle_count"))
        record.has_overhangs = _safe_bool(features.get("has_overhangs"))
        record.has_thin_walls = _safe_bool(features.get("has_thin_walls"))
        record.overhang_ratio = _safe_float(features.get("overhang_ratio"))
        record.max_overhang_angle = _safe_float(features.get("max_overhang_angle"))
        record.min_wall_thickness_mm = _safe_float(features.get("min_wall_thickness_mm"))
        record.avg_wall_thickness_mm = _safe_float(features.get("avg_wall_thickness_mm"))
        record.complexity_index = _safe_float(features.get("complexity_index"))
        record.aspect_ratio = _safe_float(features.get("aspect_ratio"))
        record.is_watertight = _safe_bool(features.get("is_watertight"))
        record.shell_count = _safe_int(features.get("shell_count"))
        record.com_offset_ratio = _safe_float(features.get("com_offset_ratio"))
        record.flat_base_area_mm2 = _safe_float(features.get("flat_base_area_mm2"))
        record.face_normal_histogram = features.get("face_normal_histogram")

        # ── Step 3: orientation optimization ─────────────────────────────────
        orientations = orientation_service.find_best_orientations(mesh)
        if len(orientations) >= 1:
            record.best_orientation_1 = orientations[0]
            record.best_orientation_score = _safe_float(orientations[0].get("score"))
        if len(orientations) >= 2:
            record.best_orientation_2 = orientations[1]
        if len(orientations) >= 3:
            record.best_orientation_3 = orientations[2]

        # ── Step 4: GLB conversion (reuses loaded mesh) ───────────────────────
        glb_path = convert_to_glb(
            input_path=file_path,
            uuid=str(stl_id),
            preloaded_mesh=mesh,
        )
        record.glb_filename = Path(glb_path).name

        # ── Step 5: mark ready ────────────────────────────────────────────────
        record.status = "ready"
        db.commit()

    except Exception:
        db.rollback()
        error_record = db.query(STLFile).filter(STLFile.id == stl_id).first()
        if error_record:
            try:
                error_record.status = "error"
                db.commit()
            except Exception:
                db.rollback()
        logger.exception("Background STL analysis failed", extra={"stl_id": str(stl_id)})
    finally:
        db.close()


def _with_glb_url(record: STLFile) -> STLFile:
    # Attach a computed URL used by the response schema without exposing disk paths.
    record.glb_url = f"/stl/{record.id}/glb" if record.glb_filename else None
    return record


def recover_pending_files(max_files: int = 50) -> None:
    """
    Best-effort startup recovery for rows stuck in uploaded/analyzing.
    Existing healthy rows are untouched.
    """
    db = SessionLocal()
    try:
        records = (
            db.query(STLFile)
            .filter(STLFile.status.in_(["uploaded", "analyzing"]))
            .order_by(STLFile.created_at.desc())
            .limit(max_files)
            .all()
        )
        db.close()

        for record in records:
            source_path = UPLOAD_DIR / record.stored_filename
            if not source_path.exists() or not source_path.is_file():
                continue
            run_analysis_pipeline(stl_id=record.id, file_path=str(source_path))
    except Exception:
        logger.exception("Failed to run STL startup recovery")
        try:
            db.close()
        except Exception:
            pass