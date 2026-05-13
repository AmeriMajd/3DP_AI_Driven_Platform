from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.schemas.invitation import ValidateInvitationResponse
from app.services.invitation_service import InvitationService


router = APIRouter(prefix="/invitations", tags=["Invitations"])


@router.get("/validate", response_model=ValidateInvitationResponse)
def validate_invitation(token: str, db: Session = Depends(get_db)):
    invitation = InvitationService(db).validate_invitation_token(token)
    return ValidateInvitationResponse(
        email=invitation.email,
        role=invitation.role,
        expires_at=invitation.expires_at,
    )
