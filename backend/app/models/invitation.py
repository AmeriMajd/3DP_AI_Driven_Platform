import uuid
from sqlalchemy import Column, String, Boolean, Enum, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from app.core.database import Base

# This class maps to the "invitations" table.
# Every time an admin generates an invitation, one row is inserted here.
# The row is marked used=True after the invited user successfully registers.

class Invitation(Base):
    __tablename__ = "invitations"

    id = Column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4
    )

    email = Column(String(255), nullable=False)
    
    role = Column(
        Enum("admin", "operator", name="invitation_role_enum"),
        nullable=False
    )
    token = Column(String(255), unique=True, nullable=False)

    created_by = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True
    )

    expires_at = Column(DateTime, nullable=False)
    used = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime, server_default=func.now(), nullable=False)