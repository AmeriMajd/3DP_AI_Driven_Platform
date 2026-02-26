from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.config import settings
from app.core.security import hash_password
from app.models.user import User
from app.models.invitation import Invitation
from app.schemas.auth import AdminSignupSchema, RegisterSchema, UserResponse
from datetime import datetime


router = APIRouter(prefix="/auth", tags=["Authentication"])

@router.post("/admin/signup", response_model=UserResponse, status_code=201)
def admin_signup(data: AdminSignupSchema, db: Session = Depends(get_db)):
    """
    Creates the very first admin account.
    Protected by ADMIN_SIGNUP_KEY — only people who know this secret
    can create admin accounts.

    Flow:
    1. Check admin_secret_key matches .env value → else 403
    2. Check email not already used → else 400
    3. Hash password with bcrypt
    4. Insert user with role='admin' (hardcoded — not from request)
    5. Return 201 with user object (no password)
    """
    if data.admin_secret_key != settings.ADMIN_SIGNUP_KEY:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid admin secret key"
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