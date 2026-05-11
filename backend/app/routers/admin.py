import secrets
import uuid as uuid_lib
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from app.core.config import settings
from app.core.database import get_db
from app.core.security import require_role
from app.models.user import User
from app.models.invitation import Invitation
from app.schemas.invitation import CreateInvitationSchema, InvitationResponse, InvitationHistoryItem

router = APIRouter(prefix="/admin", tags=["Admin"])


@router.post("/invitations", response_model=InvitationResponse, status_code=201)
def create_invitation(
    data: CreateInvitationSchema,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_role("admin"))
):
    # Step 2: Check email has no existing account
    existing_user = db.query(User).filter(User.email == data.email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This email already has an account"
        )

    # Step 3: Generate the secure token
    token = secrets.token_urlsafe(32)

    # Step 4: Set expiry
    expires_at = datetime.utcnow() + timedelta(hours=48)

    creator_id = uuid_lib.UUID(current_user["user_id"])

    # Step 5: Save to DB
    invitation = Invitation(
        email=data.email,
        role=data.role,
        token=token,
        created_by=creator_id,
        expires_at=expires_at
    )
    db.add(invitation)
    db.commit()
    db.refresh(invitation)

    # Step 6: Return 201
    shareable_link = f"{settings.APP_BASE_URL}/register?token={token}"

    return InvitationResponse(
        token=token,
        link=shareable_link,
        email=data.email,
        role=data.role,
        expires_at=expires_at
    )


@router.get("/invitations", response_model=list[InvitationHistoryItem])
def list_invitations(
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_role("admin"))
):
    invitations = (
        db.query(Invitation)
        .order_by(Invitation.created_at.desc())
        .all()
    )

    now = datetime.utcnow()
    result = []
    for inv in invitations:
        if inv.used:
            status = "used"
        elif inv.expires_at < now:
            status = "expired"
        else:
            status = "pending"

        result.append(InvitationHistoryItem(
            id=inv.id,
            email=inv.email,
            role=inv.role,
            status=status,
            created_at=inv.created_at,
            expires_at=inv.expires_at,
        ))

    return result