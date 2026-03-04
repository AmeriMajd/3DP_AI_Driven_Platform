from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import require_role
from app.models.refresh_token import RefreshToken
from app.schemas.logout import LogoutSchema, LogoutResponse

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/logout", response_model=LogoutResponse, status_code=200)
def logout(
    data: LogoutSchema,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_role("admin", "operator"))
):
    # Step 1 — require_role validates access token automatically
    # If token missing or invalid → 401 before we even get here

    # Step 2 — find the refresh token row in DB
    # Filter by both token AND user_id for security
    db_token = db.query(RefreshToken).filter(
        RefreshToken.token == data.refresh_token,
        RefreshToken.user_id == current_user["user_id"]
    ).first()

    # Step 3 — delete the row
    # If not found → already deleted → silently skip → still return 200
    if db_token:
        db.delete(db_token)
        db.commit()

    # Step 4 — always 200
    return LogoutResponse()