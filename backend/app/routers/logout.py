import uuid as uuid_lib

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import require_role
from app.schemas.logout import LogoutResponse, LogoutSchema
from app.services import activity_log_service
from app.services.session_service import SessionService


router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/logout", response_model=LogoutResponse, status_code=200)
def logout(
    data: LogoutSchema,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_role("admin", "operator")),
):
    SessionService(db).logout(current_user["user_id"], data.refresh_token)
    activity_log_service.log(
        db,
        event_type="auth",
        message="Déconnexion",
        actor_user_id=uuid_lib.UUID(current_user["user_id"]),
        severity="info",
        target_type="user",
        target_id=uuid_lib.UUID(current_user["user_id"]),
    )
    db.commit()
    return LogoutResponse()
