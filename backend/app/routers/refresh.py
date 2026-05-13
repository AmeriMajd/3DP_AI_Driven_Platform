from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.schemas.refresh import RefreshTokenResponse, RefreshTokenSchema
from app.services.session_service import SessionService


router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/refresh", response_model=RefreshTokenResponse, status_code=200)
def refresh_token(data: RefreshTokenSchema, db: Session = Depends(get_db)):
    access_token = SessionService(db).refresh_access_token(data.refresh_token)
    return RefreshTokenResponse(access_token=access_token, token_type="bearer")
