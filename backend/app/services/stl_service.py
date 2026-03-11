import uuid
from pathlib import Path

from fastapi import UploadFile, HTTPException
from sqlalchemy.orm import Session

from app.models.stl_file import STLFile

UPLOAD_DIR = Path("/app/uploads/stl")
MAX_FILE_SIZE = 50 * 1024 * 1024  # 50 MB
ALLOWED_EXTENSIONS = {".stl", ".3mf"}


def _get_extension(filename: str) -> str:
    return Path(filename).suffix.lower()


async def save_stl_file(file: UploadFile, user_id: str, db: Session) -> STLFile:
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
            status_code=400,
            detail=f"Invalid file type '{ext}'. Only .stl and .3mf files are accepted.",
        )

    # 3. Read contents and enforce size + empty-file rules
    contents = await file.read()
    if len(contents) == 0:
        raise HTTPException(status_code=400, detail="Uploaded file is empty.")

    if len(contents) > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=413,
            detail="File exceeds the 50 MB size limit.",
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

    # 6. Persist metadata — stored_filename kept in DB for deletion, never returned to client
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
        # Roll back disk write if DB insert fails
        disk_path.unlink(missing_ok=True)
        db.rollback()
        raise HTTPException(status_code=500, detail="Database error while saving file.") from exc

    return stl_record


def list_stl_files(user_id: str, db: Session) -> list[STLFile]:
    """Return all files for the current user, most recent first."""
    return (
        db.query(STLFile)
        .filter(STLFile.user_id == user_id)
        .order_by(STLFile.created_at.desc())
        .all()
    )


def get_stl_file(stl_id: str, user_id: str, db: Session) -> STLFile:
    """
    Return one file belonging to the current user.
    Returns 404 whether the file doesn't exist OR belongs to another user —
    never expose that another user's file exists.
    """
    record = (
        db.query(STLFile)
        .filter(STLFile.id == stl_id, STLFile.user_id == user_id)
        .first()
    )
    if not record:
        raise HTTPException(status_code=404, detail="File not found.")
    return record


def delete_stl_file(stl_id: str, user_id: str, db: Session) -> None:
    """Delete the physical file from disk and remove the DB row."""
    record = get_stl_file(stl_id, user_id, db)  # raises 404 if not owned

    # Remove from disk first — if this fails we can still retry; DB row still exists
    disk_path = UPLOAD_DIR / record.stored_filename
    disk_path.unlink(missing_ok=True)

    try:
        db.delete(record)
        db.commit()
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=500, detail="Database error while deleting file.") from exc