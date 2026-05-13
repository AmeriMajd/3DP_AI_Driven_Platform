import uuid as uuid_lib

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import get_db
from app.core.security import require_role
from app.schemas.invitation import (
    CreateInvitationSchema,
    InvitationHistoryItem,
    InvitationResponse,
)
from app.services.invitation_service import InvitationService

router = APIRouter(prefix="/admin", tags=["Admin"])


@router.post("/invitations", response_model=InvitationResponse, status_code=201)
def create_invitation(
    data: CreateInvitationSchema,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_role("admin")),
):
    creator_id = uuid_lib.UUID(current_user["user_id"])
    invitation = InvitationService(db).create_invitation(data, created_by=creator_id)
    shareable_link = f"{settings.APP_BASE_URL}/register?token={invitation.token}"

    return InvitationResponse(
        token=invitation.token,
        link=shareable_link,
        email=invitation.email,
        role=invitation.role,
        expires_at=invitation.expires_at,
    )


@router.get("/invitations", response_model=list[InvitationHistoryItem])
def list_invitations(
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_role("admin")),
):
    return InvitationService(db).list_invitations()
