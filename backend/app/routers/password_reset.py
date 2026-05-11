import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import hash_password
from app.core.email import send_password_reset_email
from app.models.user import User
from app.models.password_reset_token import PasswordResetToken
from app.models.refresh_token import RefreshToken
from app.schemas.password_reset import (
    ForgotPasswordSchema, ForgotPasswordResponse,
    ResetPasswordSchema, ResetPasswordResponse,
    ValidateResetTokenResponse
)

router = APIRouter(prefix="/auth", tags=["Authentication"])


def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _hash_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


@router.get("/reset-password/validate", response_model=ValidateResetTokenResponse, status_code=200)
def validate_reset_token(token: str, db: Session = Depends(get_db)):

    invalid_token_error = HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail="Invalid or expired reset token"
    )

    token_hash = _hash_token(token)
    reset_token = db.query(PasswordResetToken).filter(
        PasswordResetToken.token == token_hash
    ).first()

    if not reset_token:
        raise invalid_token_error

    if reset_token.expires_at < _utcnow():
        raise invalid_token_error

    if reset_token.used:
        raise invalid_token_error

    user = db.query(User).filter(User.id == reset_token.user_id).first()

    if not user:
        raise invalid_token_error

    return ValidateResetTokenResponse(
        email=user.email,
        expires_at=reset_token.expires_at
    )


@router.post("/forgot-password", response_model=ForgotPasswordResponse, status_code=200)
def forgot_password(data: ForgotPasswordSchema, db: Session = Depends(get_db)):

    user = db.query(User).filter(User.email == data.email).first()

    if not user:
        return ForgotPasswordResponse()

    # Rate limit: one request per minute
    recent = db.query(PasswordResetToken).filter(
        PasswordResetToken.user_id == user.id,
        PasswordResetToken.created_at > _utcnow() - timedelta(minutes=1)
    ).first()
    if recent:
        return ForgotPasswordResponse()

    # Invalidate all previous unused tokens for this user
    db.query(PasswordResetToken).filter(
        PasswordResetToken.user_id == user.id,
        PasswordResetToken.used == False  # noqa: E712
    ).delete()

    raw_token = secrets.token_urlsafe(32)
    token_hash = _hash_token(raw_token)
    expires_at = _utcnow() + timedelta(hours=1)

    reset_token = PasswordResetToken(
        user_id=user.id,
        token=token_hash,
        expires_at=expires_at
    )
    db.add(reset_token)
    db.flush()

    sent = send_password_reset_email(to_email=user.email, reset_token=raw_token)
    if not sent:
        db.rollback()
        return ForgotPasswordResponse()

    db.commit()
    return ForgotPasswordResponse()


@router.post("/reset-password", response_model=ResetPasswordResponse, status_code=200)
def reset_password(data: ResetPasswordSchema, db: Session = Depends(get_db)):

    invalid_token_error = HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail="Invalid or expired reset token"
    )

    token_hash = _hash_token(data.token)
    reset_token = db.query(PasswordResetToken).filter(
        PasswordResetToken.token == token_hash
    ).first()

    if not reset_token:
        raise invalid_token_error

    if reset_token.expires_at < _utcnow():
        raise invalid_token_error

    if reset_token.used:
        raise invalid_token_error

    user = db.query(User).filter(User.id == reset_token.user_id).first()

    if not user:
        raise invalid_token_error

    user.password = hash_password(data.new_password)
    db.flush()

    reset_token.used = True
    db.flush()

    db.query(RefreshToken).filter(
        RefreshToken.user_id == user.id
    ).delete()

    db.commit()
    return ResetPasswordResponse()
