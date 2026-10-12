from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user
from app.schemas.auth import (
    AdminSignupSchema,
    ChangePasswordSchema,
    LoginResponse,
    LoginSchema,
    RegisterSchema,
    UpdateProfileSchema,
    UserMeResponse,
    UserResponse,
)
from app.services import activity_log_service
from app.services.auth_service import AuthService
from app.services.session_service import SessionService
from app.services.user_service import UserService


router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.get("/admin/status")
def check_admin_status(db: Session = Depends(get_db)):
    return {"initialized": AuthService(db).is_admin_initialized()}


@router.post("/admin/signup", response_model=UserResponse, status_code=201)
def admin_signup(data: AdminSignupSchema, db: Session = Depends(get_db)):
    return AuthService(db).admin_signup(data)


@router.post("/register", response_model=UserResponse, status_code=201)
def register(data: RegisterSchema, db: Session = Depends(get_db)):
    return AuthService(db).register_with_invitation(data)


@router.post("/login", response_model=LoginResponse, status_code=200)
def login(data: LoginSchema, db: Session = Depends(get_db)):
    response = AuthService(db).login(data)
    activity_log_service.log(
        db,
        event_type="auth",
        message="Connexion réussie",
        actor_user_id=response.user.id,
        severity="info",
        target_type="user",
        target_id=response.user.id,
    )
    db.commit()
    return response


@router.get("/me", response_model=UserMeResponse)
def get_me(current: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    return UserService(db).get_user_me(current["user_id"])


@router.patch("/me", response_model=UserResponse)
def update_me(
    data: UpdateProfileSchema,
    current: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return UserService(db).update_profile(current["user_id"], data)


@router.patch("/me/password", status_code=200)
def change_password(
    data: ChangePasswordSchema,
    current: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    AuthService(db).change_password(current["user_id"], data)
    return {"message": "Password changed successfully"}


@router.delete("/me/sessions", status_code=200)
def revoke_all_sessions(
    current: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    SessionService(db).revoke_all_sessions(current["user_id"])
    return {"message": "All sessions revoked"}
