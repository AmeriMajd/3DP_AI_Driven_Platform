import uuid
from pathlib import Path
from fastapi import BackgroundTasks
from fastapi import UploadFile, HTTPException
from sqlalchemy.orm import Session

from app.core.database import SessionLocal
from app.models.stl_file import STLFile
import app.models.user
from app.services.geometry_service import convert_to_glb, extract_ui_features

UPLOAD_DIR = Path("/app/uploads/stl")
GLB_DIR = Path("/app/uploads/glb")
MAX_FILE_SIZE = 50 * 1024 * 1024  # 50 MB
ALLOWED_EXTENSIONS = {".stl", ".3mf"}
VALID_STATUSES = {"uploaded", "analyzing", "ready", "error"}


def _get_extension(filename: str) -> str:
    return Path(filename).suffix.lower()


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
    if not record.glb_filename:
        raise HTTPException(status_code=404, detail="GLB not available yet.")

    glb_path = GLB_DIR / record.glb_filename
    if not glb_path.exists() or not glb_path.is_file():
        raise HTTPException(status_code=404, detail="GLB not available yet.")
    return glb_path


def run_analysis_pipeline(stl_id: uuid.UUID, file_path: str) -> None:
    """
    Background pipeline:
    - mark analyzing
    - extract geometry
    - convert STL/3MF to GLB
    - mark ready
    On any failure, mark error.
    """
    db = SessionLocal()
    try:
        record = db.query(STLFile).filter(STLFile.id == stl_id).first()
        if not record:
            return

        record.status = "analyzing"
        db.commit()

        features = extract_ui_features(file_path)

        glb_path = convert_to_glb(input_path=file_path, uuid=str(stl_id))

        record.volume_cm3 = features.get("volume_cm3")
        record.surface_area_cm2 = features.get("surface_area_cm2")
        record.bbox_x_mm = features.get("bbox_x_mm")
        record.bbox_y_mm = features.get("bbox_y_mm")
        record.bbox_z_mm = features.get("bbox_z_mm")
        record.triangle_count = features.get("triangle_count")
        record.has_overhangs = features.get("has_overhangs")
        record.has_thin_walls = features.get("has_thin_walls")
        record.glb_filename = Path(glb_path).name
        record.status = "ready"

        db.commit()
    except Exception as e:
        db.rollback()
        error_record = db.query(STLFile).filter(STLFile.id == stl_id).first()
        if error_record:
            try:
                error_record.status = "error"
                db.commit()
            except Exception as err:
                db.rollback()
    finally:
        db.close()


def _with_glb_url(record: STLFile) -> STLFile:
    record.glb_url = f"/stl/{record.id}/glb" if record.glb_filename else None
    return record