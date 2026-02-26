from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime
from app.core.database import get_db
from app.models.invitation import Invitation
from app.schemas.invitation import ValidateInvitationResponse

# This router handles public invitation actions.
# No authentication required — anyone with a token can validate it.
router = APIRouter(prefix="/invitations", tags=["Invitations"])


# ─────────────────────────────────────────────────────────────
# GET /invitations/validate?token=abc123
# ─────────────────────────────────────────────────────────────

@router.get("/validate", response_model=ValidateInvitationResponse)
def validate_invitation(
    token: str,                        # FastAPI reads "token" from the query string automatically
    db: Session = Depends(get_db)
):
    """
    Called by Flutter BEFORE showing the register form.
    Checks the token is valid, not expired, and not already used.
    Returns the email and role so Flutter can pre-fill the form.

    This endpoint has NO side effects — it only reads, never writes.
    The actual registration (with DB writes) happens in POST /auth/register.

    Flow:
    1. Find invitation by token → else 400
    2. Check expires_at > NOW() → else 400
    3. Check used == False → else 400
    4. Return email + role + expires_at
    """

    # ── Step 1: Find the invitation ───────────────────────────
    invitation = db.query(Invitation).filter(
        Invitation.token == token
    ).first()

    if not invitation:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired invitation"
        )

    # ── Step 2: Check expiry ──────────────────────────────────
    # datetime.utcnow() gives current UTC time.
    # If expires_at is in the past, the invitation is no longer valid.
    if invitation.expires_at < datetime.utcnow():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired invitation"
        )

    # ── Step 3: Check not already used ───────────────────────
    if invitation.used:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired invitation"
        )

    # ── Step 4: Return the data Flutter needs ─────────────────
    # We intentionally use the same error message for all 3 failures.
    # This prevents an attacker from knowing WHY a token failed.
    return ValidateInvitationResponse(
        email=invitation.email,
        role=invitation.role,
        expires_at=invitation.expires_at
    )