from datetime import datetime, timedelta
from uuid import UUID

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import get_db
from app.models.user import User


pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
ALGORITHM = "HS256"


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


def create_access_token(data: dict) -> str:
    expire = datetime.utcnow() + timedelta(
        minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES
    )
    payload = {**data, "exp": expire}
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=ALGORITHM)


def create_refresh_token(data: dict) -> str:
    expire = datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    payload = {**data, "exp": expire, "type": "refresh"}
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=ALGORITHM)


oauth2_scheme = HTTPBearer()
bearer_scheme = HTTPBearer()


def _credentials_exception(detail: str = "Not authenticated") -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=detail,
        headers={"WWW-Authenticate": "Bearer"},
    )


def _decode_access_token(
    token: str,
    *,
    invalid_detail: str = "Not authenticated",
    missing_sub_detail: str = "Not authenticated",
) -> dict:
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[ALGORITHM])
    except JWTError:
        raise _credentials_exception(invalid_detail)

    if payload.get("sub") is None:
        raise _credentials_exception(missing_sub_detail)

    return payload


def _load_active_user(db: Session, user_id: str) -> User:
    try:
        user_uuid = UUID(str(user_id))
    except ValueError:
        raise _credentials_exception()

    user = db.query(User).filter(User.id == user_uuid).first()
    if user is None:
        raise _credentials_exception()
    if user.is_active is False:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is disabled",
        )
    return user


def require_role(*allowed_roles: str):
    def dependency(
        credentials: HTTPAuthorizationCredentials = Depends(oauth2_scheme),
        db: Session = Depends(get_db),
    ):
        payload = _decode_access_token(credentials.credentials)
        user = _load_active_user(db, payload["sub"])

        if user.role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Admin access required",
            )

        return {"user_id": str(user.id), "role": user.role}

    return dependency


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> dict:
    payload = _decode_access_token(
        credentials.credentials,
        invalid_detail="Invalid or expired token.",
        missing_sub_detail="Invalid token.",
    )
    user = _load_active_user(db, payload["sub"])
    return {"user_id": str(user.id), "role": user.role}
