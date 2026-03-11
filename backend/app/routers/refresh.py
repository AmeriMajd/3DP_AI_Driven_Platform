from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime
from jose import JWTError, jwt

from app.core.database import get_db
from app.core.config import settings
from app.core.security import create_access_token, ALGORITHM
from app.models.user import User
from app.models.refresh_token import RefreshToken
from app.schemas.refresh import RefreshTokenSchema, RefreshTokenResponse

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/refresh", response_model=RefreshTokenResponse, status_code=200)
def refresh_token(data: RefreshTokenSchema, db: Session = Depends(get_db)):

    invalid_token_error = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired refresh token"
    )

    # Check 1 & 2 — JWT signature valid + not expired
    try:
        payload = jwt.decode(
            data.refresh_token,
            settings.SECRET_KEY,
            algorithms=[ALGORITHM]
        )
        user_id: str = payload.get("sub")
        token_type: str = payload.get("type")

        if user_id is None:
            raise invalid_token_error

        if token_type != "refresh":
            raise invalid_token_error

    except JWTError:
        raise invalid_token_error

    # Check 3 — token exists in DB (not revoked)
    db_token = db.query(RefreshToken).filter(
        RefreshToken.token == data.refresh_token
    ).first()

    if not db_token:
        raise invalid_token_error

    if db_token.expires_at < datetime.utcnow():
        raise invalid_token_error

    # Load user
    user = db.query(User).filter(User.id == user_id).first()

    if not user:
        raise invalid_token_error

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is disabled"
        )

    # Generate new access token
    new_access_token = create_access_token({
        "sub": str(user.id),
        "role": user.role
    })

    return RefreshTokenResponse(
        access_token=new_access_token,
        token_type="bearer"
    )
