import secrets
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta

from app.core.database import get_db
from app.core.security import hash_password
from app.core.email import send_password_reset_email
from app.models.user import User
from app.models.password_reset_token import PasswordResetToken
from app.models.refresh_token import RefreshToken
from app.schemas.password_reset import (
    ForgotPasswordSchema, ForgotPasswordResponse,
    ResetPasswordSchema, ResetPasswordResponse
)

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/forgot-password", response_model=ForgotPasswordResponse, status_code=200)
def forgot_password(data: ForgotPasswordSchema, db: Session = Depends(get_db)):

    user = db.query(User).filter(User.email == data.email).first()

    if not user:
        return ForgotPasswordResponse()

    token = secrets.token_urlsafe(32)
    expires_at = datetime.utcnow() + timedelta(hours=1)

    reset_token = PasswordResetToken(
        user_id=user.id,
        token=token,
        expires_at=expires_at
    )
    db.add(reset_token)
    db.commit()

    send_password_reset_email(
        to_email=user.email,
        reset_token=token
    )

    return ForgotPasswordResponse()


@router.post("/reset-password", response_model=ResetPasswordResponse, status_code=200)
def reset_password(data: ResetPasswordSchema, db: Session = Depends(get_db)):

    invalid_token_error = HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail="Invalid or expired reset token"
    )

    reset_token = db.query(PasswordResetToken).filter(
        PasswordResetToken.token == data.token
    ).first()

    if not reset_token:
        raise invalid_token_error

    if reset_token.expires_at < datetime.utcnow():
        raise invalid_token_error

    if reset_token.used:
        raise invalid_token_error

    new_hashed_password = hash_password(data.new_password)

    user = db.query(User).filter(User.id == reset_token.user_id).first()

    if not user:
        raise invalid_token_error

    user.password = new_hashed_password
    db.flush()

    reset_token.used = True
    db.flush()

    db.query(RefreshToken).filter(
        RefreshToken.user_id == user.id
    ).delete()

    db.commit()

    return ResetPasswordResponse()