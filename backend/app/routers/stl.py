from uuid import UUID

from fastapi import APIRouter, Depends, UploadFile, File, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user
from app.schemas.stl import STLFileResponse, STLListResponse
from app.services import stl_service

router = APIRouter(prefix="/stl", tags=["STL Files"])


@router.post(
    "/upload",
    response_model=STLFileResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Upload an STL or 3MF file",
)
async def upload_stl(
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    record = await stl_service.save_stl_file(
        file=file,
        user_id=current_user["user_id"],
        db=db,
    )
    return record


@router.get(
    "/",
    response_model=STLListResponse,
    status_code=status.HTTP_200_OK,
    summary="List all files uploaded by the current user",
)
def list_files(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    files = stl_service.list_stl_files(
        user_id=current_user["user_id"],
        db=db,
    )
    return STLListResponse(total=len(files), files=files)


@router.get(
    "/{stl_id}",
    response_model=STLFileResponse,
    status_code=status.HTTP_200_OK,
    summary="Get metadata for a specific file",
)
def get_file(
    stl_id: UUID,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return stl_service.get_stl_file(
        stl_id=stl_id,
        user_id=current_user["user_id"],
        db=db,
    )


@router.delete(
    "/{stl_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a file — owner only",
)
def delete_file(
    stl_id: UUID,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    stl_service.delete_stl_file(
        stl_id=stl_id,
        user_id=current_user["user_id"],
        db=db,
    )