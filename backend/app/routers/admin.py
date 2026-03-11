import secrets
import uuid as uuid_lib
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from app.core.database import get_db
from app.core.security import require_role
from app.models.user import User
from app.models.invitation import Invitation
from app.schemas.invitation import CreateInvitationSchema, InvitationResponse

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

    # TODO: remove after login endpoint is built
    try:
        creator_id = uuid_lib.UUID(current_user["user_id"])
    except (ValueError, AttributeError):
        creator_id = None

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
    shareable_link = f"https://3dpapp.com/register?token={token}"

    return InvitationResponse(
        token=token,
        link=shareable_link,
        email=data.email,
        role=data.role,
        expires_at=expires_at
    )