from datetime import datetime, timedelta
from uuid import UUID

from fastapi import HTTPException, status
from jose import JWTError, jwt
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import ALGORITHM, create_access_token, create_refresh_token
from app.models.refresh_token import RefreshToken
from app.models.user import User


class SessionService:
    def __init__(self, db: Session):
        self.db = db

    def create_session(self, user: User) -> tuple[str, str]:
        access_token = create_access_token({"sub": str(user.id), "role": user.role})
        refresh_token = create_refresh_token({"sub": str(user.id)})
        expires_at = datetime.utcnow() + timedelta(
            days=settings.REFRESH_TOKEN_EXPIRE_DAYS
        )

        db_token = RefreshToken(
            user_id=user.id,
            token=refresh_token,
            expires_at=expires_at,
        )
        self.db.add(db_token)
        self.db.commit()

        return access_token, refresh_token

    def refresh_access_token(self, refresh_token: str) -> str:
        payload = self._decode_refresh_token(refresh_token)
        user_id = self._parse_user_id(payload.get("sub"))

        db_token = (
            self.db.query(RefreshToken)
            .filter(RefreshToken.token == refresh_token)
            .first()
        )
        if db_token is None or db_token.expires_at < datetime.utcnow():
            raise self._invalid_refresh_token_error()

        user = self.db.query(User).filter(User.id == user_id).first()
        if user is None:
            raise self._invalid_refresh_token_error()
        if not user.is_active:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Account is disabled",
            )

        return create_access_token({"sub": str(user.id), "role": user.role})

    def logout(self, user_id: str | UUID, refresh_token: str) -> None:
        db_token = (
            self.db.query(RefreshToken)
            .filter(
                RefreshToken.token == refresh_token,
                RefreshToken.user_id == self._parse_user_id(user_id),
            )
            .first()
        )

        if db_token is not None:
            self.db.delete(db_token)
            self.db.commit()

    def revoke_all_sessions(self, user_id: str | UUID) -> None:
        self.db.query(RefreshToken).filter(
            RefreshToken.user_id == self._parse_user_id(user_id)
        ).delete()
        self.db.commit()

    def _decode_refresh_token(self, token: str) -> dict:
        try:
            payload = jwt.decode(
                token,
                settings.SECRET_KEY,
                algorithms=[ALGORITHM],
            )
        except JWTError:
            raise self._invalid_refresh_token_error()

        if payload.get("type") != "refresh":
            raise self._invalid_refresh_token_error()
        if payload.get("sub") is None:
            raise self._invalid_refresh_token_error()

        return payload

    def _parse_user_id(self, user_id: str | UUID | None) -> UUID:
        if isinstance(user_id, UUID):
            return user_id
        if user_id is None:
            raise self._invalid_refresh_token_error()
        try:
            return UUID(str(user_id))
        except ValueError:
            raise self._invalid_refresh_token_error()

    def _invalid_refresh_token_error(self) -> HTTPException:
        return HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token",
        )
