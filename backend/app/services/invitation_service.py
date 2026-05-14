import secrets
from datetime import datetime, timedelta
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.invitation import Invitation
from app.models.user import User
from app.schemas.invitation import CreateInvitationSchema, InvitationHistoryItem


class InvitationService:
    invalid_invitation_error = HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail="Invalid or expired invitation",
    )

    def __init__(self, db: Session):
        self.db = db

    def create_invitation(
        self,
        data: CreateInvitationSchema,
        created_by: UUID,
    ) -> Invitation:
        existing_user = self.db.query(User).filter(User.email == data.email).first()
        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="This email already has an account",
            )

        invitation = Invitation(
            email=data.email,
            role=data.role,
            token=secrets.token_urlsafe(32),
            created_by=created_by,
            expires_at=datetime.utcnow() + timedelta(hours=48),
        )
        self.db.add(invitation)
        self.db.commit()
        self.db.refresh(invitation)
        return invitation

    def validate_invitation_token(self, token: str) -> Invitation:
        invitation = (
            self.db.query(Invitation)
            .filter(Invitation.token == token)
            .first()
        )

        if invitation is None:
            raise self.invalid_invitation_error
        if invitation.expires_at < datetime.utcnow():
            raise self.invalid_invitation_error
        if invitation.used:
            raise self.invalid_invitation_error

        return invitation

    def consume_invitation(self, token: str) -> Invitation:
        invitation = self.validate_invitation_token(token)
        invitation.used = True
        return invitation

    def resend_invitation(self, invitation_id: UUID) -> Invitation:
        invitation = (
            self.db.query(Invitation)
            .filter(Invitation.id == invitation_id)
            .first()
        )
        if invitation is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Invitation not found",
            )
        if invitation.used:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invitation already used",
            )

        # Rate limit: reject if last (re)send happened less than 1 hour ago.
        # Tokens get a fresh 48h window on each (re)send, so >47h remaining
        # means the last send is younger than 1h.
        if invitation.expires_at - datetime.utcnow() > timedelta(hours=47):
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Invitation was sent less than an hour ago. Try again later.",
            )

        invitation.token = secrets.token_urlsafe(32)
        invitation.expires_at = datetime.utcnow() + timedelta(hours=48)
        self.db.commit()
        self.db.refresh(invitation)
        return invitation

    def list_invitations(self) -> list[InvitationHistoryItem]:
        invitations = (
            self.db.query(Invitation)
            .order_by(Invitation.created_at.desc())
            .all()
        )

        return [
            InvitationHistoryItem(
                id=invitation.id,
                email=invitation.email,
                role=invitation.role,
                status=self.get_invitation_status(invitation),
                created_at=invitation.created_at,
                expires_at=invitation.expires_at,
            )
            for invitation in invitations
        ]

    def get_invitation_status(self, invitation: Invitation) -> str:
        if invitation.used:
            return "used"
        if invitation.expires_at < datetime.utcnow():
            return "expired"
        return "pending"
