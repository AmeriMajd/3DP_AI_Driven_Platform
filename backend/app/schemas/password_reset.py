from datetime import datetime
from pydantic import BaseModel, EmailStr, field_validator


class ForgotPasswordSchema(BaseModel):
    email: EmailStr


class ForgotPasswordResponse(BaseModel):
    detail: str = "If this email exists, a reset link has been sent"


class ResetPasswordSchema(BaseModel):
    token: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def password_min_length(cls, v):
        if len(v) < 8:
            raise ValueError("new_password must be at least 8 characters")
        return v


class ResetPasswordResponse(BaseModel):
    detail: str = "Password updated successfully"


class ValidateResetTokenResponse(BaseModel):
    email: str
    expires_at: datetime