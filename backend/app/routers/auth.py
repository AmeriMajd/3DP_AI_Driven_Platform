from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.core.database import get_db
from app.core.config import settings
from app.core.security import hash_password, get_current_user
from app.models.user import User
from app.models.invitation import Invitation
from app.models.stl_file import STLFile
from app.models.recommendation import Recommendation
from app.models.print_job import PrintJob
from app.schemas.auth import (
    AdminSignupSchema, RegisterSchema, UserResponse,
    LoginSchema, LoginResponse, UserProfile,
    UserMeResponse, UserStats, UpdateProfileSchema, ChangePasswordSchema,
)
from datetime import datetime, timedelta
from app.core.security import verify_password, create_access_token, create_refresh_token
from app.models.refresh_token import RefreshToken


router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.get("/admin/status")
def check_admin_status(db: Session = Depends(get_db)):
    count = db.query(func.count()).select_from(User).filter(User.role == "admin").scalar()
    return {"initialized": count > 0}


@router.post("/admin/signup", response_model=UserResponse, status_code=201)
def admin_signup(data: AdminSignupSchema, db: Session = Depends(get_db)):
    if data.admin_secret_key != settings.ADMIN_SIGNUP_KEY:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid admin secret key"
        )

    admin_count = db.query(func.count()).select_from(User).filter(User.role == "admin").scalar()
    if admin_count > 0:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin already exists"
        )

    existing = db.query(User).filter(User.email == data.email).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )

    hashed = hash_password(data.password)
    new_user = User(
        full_name=data.full_name,
        email=data.email,
        password=hashed,
        role="admin"           # hardcoded — never from request body
    )
    db.add(new_user)          
    db.commit()                
    db.refresh(new_user)       

    return new_user

@router.post("/register", response_model=UserResponse, status_code=201)
def register(data: RegisterSchema, db: Session = Depends(get_db)):
    """
    Creates a user account using an invitation token.
    The token must be valid, not expired, and not already used.
    Email and role come FROM the token — the user cannot override them.

    Flow:
    1. Find the invitation by token → else 400
    2. Check not expired AND not used → else 400
    3. Hash password
    4. Create user with email + role from invitation
    5. Mark invitation as used
    6. Return 201
    """

    invitation = db.query(Invitation).filter(
        Invitation.token == data.token
    ).first()

    if not invitation:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired invitation"
        )
    if (invitation.expires_at < datetime.utcnow()) is True:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired invitation"
        )
    if invitation.used is True:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired invitation"
        )

    hashed = hash_password(data.password)
    new_user = User(
        full_name=data.full_name,
        email=invitation.email,    # from invitation, not request
        password=hashed,
        role=invitation.role       # from invitation, not request
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    invitation.used = True # type: ignore
    db.commit()

    return new_user


@router.post("/login", response_model=LoginResponse, status_code=200)
def login(data: LoginSchema, db: Session = Depends(get_db)):
    # 1) Find user by email
    user = db.query(User).filter(User.email == data.email).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials"
        )

    # 2) Verify password (bcrypt)
    if not verify_password(data.password, user.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials"
        )

    # 3) Check is_active
    if user.is_active is False:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is disabled"
        )

    # 4) Create access token: includes sub + role
    access_token = create_access_token({"sub": str(user.id), "role": user.role})

    # 5) Create refresh token: includes sub; create_refresh_token adds type="refresh"
    refresh_token = create_refresh_token({"sub": str(user.id)})

    # 6) Persist refresh token in DB
    expires_at = datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    db_token = RefreshToken(user_id=user.id, token=refresh_token, expires_at=expires_at)
    db.add(db_token)
    db.commit()

    # 7) Return tokens + user profile
    return LoginResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user=UserProfile.model_validate(user)
    )


@router.get("/me", response_model=UserMeResponse)
def get_me(current: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == current["user_id"]).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    files_count = db.query(func.count()).select_from(STLFile).filter(STLFile.user_id == user.id).scalar()
    recs_count = db.query(func.count()).select_from(Recommendation).filter(Recommendation.user_id == user.id).scalar()
    jobs_count = db.query(func.count()).select_from(PrintJob).filter(PrintJob.user_id == user.id).scalar()

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
        conflict = db.query(User).filter(User.email == data.email, User.id != user.id).first()
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
    user = db.query(User).filter(User.id == current["user_id"]).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if not verify_password(data.current_password, user.password):
        raise HTTPException(status_code=400, detail="Current password is incorrect")

    user.password = hash_password(data.new_password)
    db.commit()
    return {"message": "Password changed successfully"}


@router.delete("/me/sessions", status_code=200)
def revoke_all_sessions(
    current: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    db.query(RefreshToken).filter(RefreshToken.user_id == current["user_id"]).delete()
    db.commit()
    return {"message": "All sessions revoked"}