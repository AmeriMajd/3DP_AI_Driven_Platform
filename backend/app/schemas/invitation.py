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
    Only operators can be invited — there is a single admin (the first admin).
    Anything other than "operator" returns 422 automatically.
    """
    email: EmailStr
    role: Literal["operator"]


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


# ── INVITATION HISTORY ITEM ───────────────────

class InvitationHistoryItem(BaseModel):
    """
    One row in GET /admin/invitations response.
    status is computed: 'used' | 'expired' | 'pending'.
    """
    id: UUID
    email: str
    role: str
    status: str
    created_at: datetime
    expires_at: datetime

    model_config = {"from_attributes": True}