from pydantic import BaseModel, EmailStr
from datetime import datetime
from uuid import UUID
from typing import Literal

# ─────────────────────────────────────────────
# Schemas for the invitation endpoints.
# ─────────────────────────────────────────────


# ── CREATE INVITATION (admin sends this) ──────

class CreateInvitationSchema(BaseModel):
    """
    Request body for POST /admin/invitations.
    The admin specifies who to invite and what role they will have.
    Literal["admin", "operator"] restricts the value to exactly
    these two strings. Anything else returns 422 automatically.
    """
    email: EmailStr
    role: Literal["admin", "operator"]


# ── INVITATION RESPONSE (what we return) ──────

class InvitationResponse(BaseModel):
    """
    Returned after a successful invitation creation.
    Contains the token and the shareable link the admin
    can copy and send to the invited user.
    """
    token: str
    link: str
    email: str
    role: str
    expires_at: datetime

    model_config = {"from_attributes": True}


# ── VALIDATE RESPONSE (token check result) ────

class ValidateInvitationResponse(BaseModel):
    """
    Returned by GET /invitations/validate.
    Flutter uses this to pre-fill the register form.
    email and role come from the invitation — the user sees
    them but cannot edit them.
    """
    email: str
    role: str
    expires_at: datetime

    model_config = {"from_attributes": True}