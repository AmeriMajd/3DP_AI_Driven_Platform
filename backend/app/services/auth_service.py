from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import hash_password, verify_password
from app.models.user import User
from app.schemas.auth import (
    AdminSignupSchema,
    ChangePasswordSchema,
    LoginResponse,
    LoginSchema,
    RegisterSchema,
    UserProfile,
)
from app.services.invitation_service import InvitationService
from app.services.session_service import SessionService


class AuthService:
    def __init__(self, db: Session):
        self.db = db

    def is_admin_initialized(self) -> bool:
        count = (
            self.db.query(func.count())
            .select_from(User)
            .filter(User.role == "admin")
            .scalar()
        )
        return count > 0

    def admin_signup(self, data: AdminSignupSchema) -> User:
        if data.admin_secret_key != settings.ADMIN_SIGNUP_KEY:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Invalid admin secret key",
            )

        if self.is_admin_initialized():
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Admin already exists",
            )

        existing = self.db.query(User).filter(User.email == data.email).first()
        if existing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already registered",
            )

        user = User(
            full_name=data.full_name,
            email=data.email,
            password=hash_password(data.password),
            role="admin",
        )
        self.db.add(user)
        self.db.commit()
        self.db.refresh(user)
        return user

    def register_with_invitation(self, data: RegisterSchema) -> User:
        invitation = InvitationService(self.db).consume_invitation(data.token)
        user = User(
            full_name=data.full_name,
            email=invitation.email,
            password=hash_password(data.password),
            role=invitation.role,
        )
        self.db.add(user)
        self.db.commit()
        self.db.refresh(user)
        return user

    def login(self, data: LoginSchema) -> LoginResponse:
        user = self.authenticate_user(data.email, data.password)
        access_token, refresh_token = SessionService(self.db).create_session(user)

        return LoginResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            user=UserProfile.model_validate(user),
        )

    def authenticate_user(self, email: str, password: str) -> User:
        user = self.db.query(User).filter(User.email == email).first()
        if user is None:
            raise self._invalid_credentials_error()
        if not verify_password(password, user.password):
            raise self._invalid_credentials_error()
        if user.is_active is False:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Account is disabled",
            )
        return user

    def change_password(self, user_id: str | UUID, data: ChangePasswordSchema) -> None:
        user = self.db.query(User).filter(User.id == self._parse_user_id(user_id)).first()
        if user is None:
            raise HTTPException(status_code=404, detail="User not found")

        if not verify_password(data.current_password, user.password):
            raise HTTPException(status_code=400, detail="Current password is incorrect")

        user.password = hash_password(data.new_password)
        self.db.commit()

    def _parse_user_id(self, user_id: str | UUID) -> UUID:
        if isinstance(user_id, UUID):
            return user_id
        return UUID(str(user_id))

    def _invalid_credentials_error(self) -> HTTPException:
        return HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
        )
