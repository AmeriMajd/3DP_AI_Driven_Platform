import uuid as uuid_lib
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, status  # BackgroundTasks used by resend
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.email import send_invitation_email
from app.core.security import require_role
from app.models.invitation import Invitation
from app.models.print_job import PrintJob
from app.models.user import User
from app.schemas.activity_log import ActivityLogPage, ActivityLogResponse
from app.schemas.invitation import (
    CreateInvitationSchema,
    InvitationHistoryItem,
    InvitationResponse,
)
from app.schemas.admin_dashboard import (
    ActiveJobItem,
    DashboardKpis,
    JobsByStatusPoint,
    RecentJobItem,
    RevenuePoint,
    TopUserItem,
)
from app.schemas.user import UserListItem
from app.services import activity_log_service
from app.services.admin_dashboard_service import AdminDashboardService
from app.services.invitation_service import InvitationService

router = APIRouter(prefix="/admin", tags=["Admin"])


@router.post("/invitations", response_model=InvitationResponse, status_code=201)
def create_invitation(
    data: CreateInvitationSchema,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_role("admin")),
):
    creator_id = uuid_lib.UUID(current_user["user_id"])
    invitation = InvitationService(db).create_invitation(data, created_by=creator_id)
    activity_log_service.log(
        db,
        event_type="admin",
        message=f"Invitation envoyée à {invitation.email}",
        actor_user_id=creator_id,
        severity="info",
        target_type="user",
        target_id=None,
        metadata={"email": invitation.email, "role": invitation.role},
    )
    db.commit()

    return InvitationResponse(
        id=invitation.id,
        email=invitation.email,
        role=invitation.role,
        expires_at=invitation.expires_at,
        email_sent=False,
        token=invitation.token,
    )


@router.post("/invitations/{invitation_id}/send-email", response_model=InvitationResponse)
def send_invitation_email_endpoint(
    invitation_id: str,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_role("admin")),
):
    invitation = InvitationService(db).send_invitation_email(uuid_lib.UUID(invitation_id))

    background_tasks.add_task(
        send_invitation_email,
        invitation.email,
        invitation.token,
        invitation.role,
        None,
    )

    return InvitationResponse(
        id=invitation.id,
        email=invitation.email,
        role=invitation.role,
        expires_at=invitation.expires_at,
        email_sent=True,
        token=invitation.token,
    )


@router.get("/invitations", response_model=list[InvitationHistoryItem])
def list_invitations(
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_role("admin")),
):
    return InvitationService(db).list_invitations()


@router.delete("/invitations/{invitation_id}", status_code=204)
def cancel_invitation(
    invitation_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_role("admin")),
):
    invitation = (
        db.query(Invitation)
        .filter(Invitation.id == uuid_lib.UUID(invitation_id))
        .first()
    )
    if not invitation:
        raise HTTPException(status_code=404, detail="Invitation not found")
    if invitation.used:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot cancel a used invitation",
        )
    db.delete(invitation)
    db.commit()


@router.get("/users", response_model=list[UserListItem])
def list_users(
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_role("admin")),
):
    users = db.query(User).order_by(User.created_at).all()
    result = []
    for user in users:
        jobs_count = (
            db.query(PrintJob).filter(PrintJob.user_id == user.id).count()
        )
        result.append(
            UserListItem(
                id=user.id,
                full_name=user.full_name,
                email=user.email,
                role=user.role,
                is_active=user.is_active,
                created_at=user.created_at,
                jobs_count=jobs_count,
            )
        )
    return result


@router.delete("/users/{user_id}", status_code=204)
def delete_user(
    user_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_role("admin")),
):
    if user_id == current_user["user_id"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot delete yourself",
        )
    user = db.query(User).filter(User.id == uuid_lib.UUID(user_id)).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.is_active = False
    activity_log_service.log(
        db,
        event_type="admin",
        message=f"Utilisateur désactivé: {user.email}",
        actor_user_id=uuid_lib.UUID(current_user["user_id"]),
        severity="warning",
        target_type="user",
        target_id=user.id,
    )
    db.commit()


# ── Activity log ────────────────────────────────────────────────


@router.get("/activity", response_model=ActivityLogPage)
def list_activity(
    date_from: Optional[datetime] = Query(None),
    date_to: Optional[datetime] = Query(None),
    event_type: Optional[str] = Query(None),
    severity: Optional[str] = Query(None),
    actor_user_id: Optional[str] = Query(None),
    target_type: Optional[str] = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_role("admin")),
):
    actor_uuid = uuid_lib.UUID(actor_user_id) if actor_user_id else None
    rows, total = activity_log_service.query(
        db,
        date_from=date_from,
        date_to=date_to,
        event_type=event_type,
        severity=severity,
        actor_user_id=actor_uuid,
        target_type=target_type,
        limit=limit,
        offset=offset,
    )

    actor_ids = {r.actor_user_id for r in rows if r.actor_user_id is not None}
    name_by_id: dict = {}
    if actor_ids:
        users = db.query(User.id, User.full_name).filter(User.id.in_(actor_ids)).all()
        name_by_id = {u.id: u.full_name for u in users}

    items = []
    for r in rows:
        item = ActivityLogResponse.model_validate(r)
        item.actor_name = name_by_id.get(r.actor_user_id)
        items.append(item)
    return ActivityLogPage(items=items, total=total, limit=limit, offset=offset)


# ── Dashboard ───────────────────────────────────────────────


@router.get("/dashboard/kpis", response_model=DashboardKpis)
def dashboard_kpis(
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_role("admin")),
):
    return AdminDashboardService(db).kpis()


@router.get("/dashboard/revenue", response_model=list[RevenuePoint])
def dashboard_revenue(
    range: str = "30d",
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_role("admin")),
):
    return AdminDashboardService(db).revenue_series(range)


@router.get("/dashboard/jobs-by-status", response_model=list[JobsByStatusPoint])
def dashboard_jobs_by_status(
    range: str = "30d",
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_role("admin")),
):
    return AdminDashboardService(db).jobs_by_status_series(range)


@router.get("/dashboard/active-jobs", response_model=list[ActiveJobItem])
def dashboard_active_jobs(
    limit: int = 12,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_role("admin")),
):
    return AdminDashboardService(db).active_jobs(limit=limit)


@router.get("/dashboard/recent-jobs", response_model=list[RecentJobItem])
def dashboard_recent_jobs(
    filter: str | None = None,
    limit: int = 20,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_role("admin")),
):
    return AdminDashboardService(db).recent_jobs(filter, limit=limit)


@router.get("/dashboard/top-users", response_model=list[TopUserItem])
def dashboard_top_users(
    range: str = "30d",
    limit: int = 5,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_role("admin")),
):
    return AdminDashboardService(db).top_users(range, limit=limit)
