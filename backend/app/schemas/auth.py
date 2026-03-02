from pydantic import BaseModel, EmailStr, field_validator
from datetime import datetime
from uuid import UUID

# ─────────────────────────────────────────────
# Pydantic schemas are NOT the database models.
# They define what data comes IN (request body)
# and what data goes OUT (response body).
# Pydantic validates automatically — if a field
# fails validation, FastAPI returns 422 before
# your code even runs.
# ─────────────────────────────────────────────


# ── ADMIN SIGNUP ─────────────────────────────

class AdminSignupSchema(BaseModel):
    """
    Request body for POST /auth/admin/signup.
    The admin_secret_key is checked against ADMIN_SIGNUP_KEY in .env.
    If it does not match, we raise 403 before touching the database.
    """
    full_name: str
    email: EmailStr          # EmailStr validates format automatically (requires email-validator package)
    password: str
    admin_secret_key: str

    # @field_validator runs after the basic type check.
    # "mode='before'" means it runs before Pydantic's own validation.
    @field_validator("full_name")
    @classmethod
    def name_min_length(cls, v):
        if len(v.strip()) < 2:
            raise ValueError("full_name must be at least 2 characters")
        return v.strip()

    @field_validator("password")
    @classmethod
    def password_min_length(cls, v):
        if len(v) < 8:
            raise ValueError("password must be at least 8 characters")
        return v


# ── REGISTER (via invitation token) ──────────

class RegisterSchema(BaseModel):
    """
    Request body for POST /auth/register.
    Notice: NO email field, NO role field.
    Both come from the invitation token, not from the user.
    """
    token: str               # The invitation token from the URL
    full_name: str
    password: str

    @field_validator("full_name")
    @classmethod
    def name_min_length(cls, v):
        if len(v.strip()) < 2:
            raise ValueError("full_name must be at least 2 characters")
        return v.strip()

    @field_validator("password")
    @classmethod
    def password_min_length(cls, v):
        if len(v) < 8:
            raise ValueError("password must be at least 8 characters")
        return v


# ── USER RESPONSE ─────────────────────────────

class UserResponse(BaseModel):
    """
    What we return after a successful signup or register.
    NEVER include the password field here — not even the hash.
    The 'from_attributes=True' tells Pydantic to read data
    from a SQLAlchemy model object (not just from a dict).
    """
    id: UUID
    email: str
    full_name: str
    role: str
    created_at: datetime

    model_config = {"from_attributes": True}

class LoginSchema(BaseModel):
    email: EmailStr
    password: str

    @field_validator("password")
    @classmethod
    def password_min_length(cls, v):
        if len(v) < 8:
            raise ValueError("password must be at least 8 characters")
        return v

class UserProfile(BaseModel):
    id: UUID
    full_name: str
    role: str
    model_config = {"from_attributes": True}

class LoginResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserProfile