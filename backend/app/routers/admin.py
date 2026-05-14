import uuid as uuid_lib

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import get_db
from app.core.security import require_role
from app.models.invitation import Invitation
from app.models.print_job import PrintJob
from app.models.user import User
from app.schemas.invitation import (
    CreateInvitationSchema,
    InvitationHistoryItem,
    InvitationResponse,
)
from app.schemas.user import UserListItem
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


@router.delete("/invitations/{invitation_id}", status_code=204)
def cancel_invitation(
    invitation_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_role("admin")),
):
    invitation = (
        db.query(Invitation)
        .filter(Invitation.id == uuid_lib.UUID(invitation_id))
        .first()
    )
    if not invitation:
        raise HTTPException(status_code=404, detail="Invitation not found")
    if invitation.used:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot cancel a used invitation",
        )
    db.delete(invitation)
    db.commit()


@router.get("/users", response_model=list[UserListItem])
def list_users(
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_role("admin")),
):
    users = db.query(User).order_by(User.created_at).all()
    result = []
    for user in users:
        jobs_count = (
            db.query(PrintJob).filter(PrintJob.user_id == user.id).count()
        )
        result.append(
            UserListItem(
                id=user.id,
                full_name=user.full_name,
                email=user.email,
                role=user.role,
                is_active=user.is_active,
                created_at=user.created_at,
                jobs_count=jobs_count,
            )
        )
    return result


@router.delete("/users/{user_id}", status_code=204)
def delete_user(
    user_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_role("admin")),
):
    if user_id == current_user["user_id"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot delete yourself",
        )
    user = db.query(User).filter(User.id == uuid_lib.UUID(user_id)).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    db.delete(user)
    db.commit()
