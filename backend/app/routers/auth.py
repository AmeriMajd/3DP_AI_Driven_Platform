from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.print_job import PrintJob
from app.models.recommendation import Recommendation
from app.models.refresh_token import RefreshToken
from app.models.stl_file import STLFile
from app.models.user import User
from app.schemas.auth import (
    AdminSignupSchema,
    ChangePasswordSchema,
    LoginResponse,
    LoginSchema,
    RegisterSchema,
    UpdateProfileSchema,
    UserMeResponse,
    UserResponse,
    UserStats,
)
from app.services.auth_service import AuthService
from app.services.session_service import SessionService


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
    return AuthService(db).login(data)


@router.get("/me", response_model=UserMeResponse)
def get_me(current: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == current["user_id"]).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    files_count = (
        db.query(func.count())
        .select_from(STLFile)
        .filter(STLFile.user_id == user.id)
        .scalar()
    )
    recs_count = (
        db.query(func.count())
        .select_from(Recommendation)
        .filter(Recommendation.user_id == user.id)
        .scalar()
    )
    jobs_count = (
        db.query(func.count())
        .select_from(PrintJob)
        .filter(PrintJob.user_id == user.id)
        .scalar()
    )

    last_token = (
        db.query(RefreshToken)
        .filter(RefreshToken.user_id == user.id)
        .order_by(RefreshToken.created_at.desc())
        .first()
    )

    return UserMeResponse(
        id=user.id,
        email=user.email,
        full_name=user.full_name,
        role=user.role,
        created_at=user.created_at,
        last_login=last_token.created_at if last_token else None,
        stats=UserStats(
            files_uploaded=files_count or 0,
            recommendations_count=recs_count or 0,
            jobs_submitted=jobs_count or 0,
        ),
    )


@router.patch("/me", response_model=UserResponse)
def update_me(
    data: UpdateProfileSchema,
    current: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.id == current["user_id"]).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if data.full_name:
        user.full_name = data.full_name
    if data.email:
        conflict = (
            db.query(User)
            .filter(User.email == data.email, User.id != user.id)
            .first()
        )
        if conflict:
            raise HTTPException(status_code=400, detail="Email already in use")
        user.email = data.email

    db.commit()
    db.refresh(user)
    return user


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
