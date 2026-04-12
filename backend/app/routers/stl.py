from uuid import UUID
from fastapi import APIRouter, Depends, UploadFile, File, status
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.security import get_current_user
from app.schemas.stl import STLFileResponse, STLListResponse, STLStatusUpdate
from app.services import stl_service
from fastapi import BackgroundTasks

router = APIRouter(prefix="/stl", tags=["STL Files"])


@router.post(
    "/upload",
    response_model=STLFileResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Upload an STL or 3MF file",
)
async def upload_stl(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return await stl_service.save_stl_file(
        file=file,
        user_id=current_user["user_id"],
        db=db,
        background_tasks=background_tasks,
    )


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


@router.patch(
    "/{stl_id}/status",
    response_model=STLFileResponse,
    status_code=status.HTTP_200_OK,
    summary="Update the processing status of a file",
)
def update_status(
    stl_id: UUID,
    payload: STLStatusUpdate,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return stl_service.update_stl_status(
        stl_id=stl_id,
        user_id=current_user["user_id"],
        new_status=payload.status,
        db=db,
    )


@router.post(
    "/{stl_id}/reprocess",
    response_model=STLFileResponse,
    status_code=status.HTTP_202_ACCEPTED,
    summary="Re-run analysis pipeline for a file",
)
def reprocess_file(
    stl_id: UUID,
    background_tasks: BackgroundTasks,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return stl_service.queue_reprocess(
        stl_id=stl_id,
        user_id=current_user["user_id"],
        db=db,
        background_tasks=background_tasks,
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


@router.get(
    "/{stl_id}/glb",
    status_code=status.HTTP_200_OK,
    summary="Download converted GLB for a file (owner only)",
)
def download_glb(
    stl_id: UUID,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    glb_path = stl_service.get_glb_path(
        stl_id=stl_id,
        user_id=current_user["user_id"],
        db=db,
    )
    return FileResponse(
        path=str(glb_path),
        media_type="application/octet-stream",
        filename=glb_path.name,
    )