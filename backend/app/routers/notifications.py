"""Notifications router — in-app history + device registration.

Endpoints:
  GET    /notifications                     — paginated history (auth)
  GET    /notifications/unread-count        — small payload for the bell badge
  POST   /notifications/{id}/read           — mark single notification read
  POST   /notifications/read-all            — bulk mark-read
  POST   /notifications/devices             — register an FCM token
  DELETE /notifications/devices/{token}     — unregister (logout / token rotation)
"""

from datetime import datetime
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import and_
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.notification import Notification
from app.models.user_device import UserDevice
from app.schemas.notification import (
    DeviceRead,
    DeviceRegister,
    NotificationListResponse,
    NotificationRead,
    UnreadCountResponse,
)
from app.services import notification_service

router = APIRouter(prefix="/notifications", tags=["Notifications"])


def _user_uuid(current_user: dict) -> UUID:
    return UUID(current_user["user_id"])


# ── History ───────────────────────────────────────────────────────────────────


@router.get("", response_model=NotificationListResponse)
def list_notifications(
    category: Optional[str] = Query(default=None),
    severity: Optional[list[str]] = Query(default=None),
    unread_only: bool = Query(default=False),
    cursor: Optional[datetime] = Query(
        default=None,
        description="ISO timestamp; returns notifications strictly older than this.",
    ),
    limit: int = Query(default=30, ge=1, le=100),
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    user_id = _user_uuid(current_user)
    rows = notification_service.list_for_user(
        db,
        user_id=user_id,
        category=category,
        severities=severity,
        unread_only=unread_only,
        before=cursor,
        limit=limit,
    )
    next_cursor = rows[-1].created_at.isoformat() if len(rows) == limit else None
    return NotificationListResponse(
        items=[NotificationRead.model_validate(r) for r in rows],
        next_cursor=next_cursor,
        unread_count=notification_service.unread_count(db, user_id=user_id),
    )


@router.get("/unread-count", response_model=UnreadCountResponse)
def get_unread_count(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return UnreadCountResponse(
        unread_count=notification_service.unread_count(
            db, user_id=_user_uuid(current_user)
        )
    )


@router.post("/{notification_id}/read", response_model=NotificationRead)
def mark_read(
    notification_id: UUID,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    user_id = _user_uuid(current_user)
    ok = notification_service.mark_read(
        db, user_id=user_id, notification_id=notification_id
    )
    if not ok:
        # 404 instead of 403 — don't leak existence of someone else's row.
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    db.commit()
    row = db.get(Notification, notification_id)
    return NotificationRead.model_validate(row)


@router.post("/read-all")
def mark_all_read(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    affected = notification_service.mark_all_read(
        db, user_id=_user_uuid(current_user)
    )
    db.commit()
    return {"affected": affected}


# ── Device registration (FCM tokens) ─────────────────────────────────────────


@router.post(
    "/devices",
    response_model=DeviceRead,
    status_code=status.HTTP_201_CREATED,
)
def register_device(
    payload: DeviceRegister,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Idempotent register: if the token already exists, update ownership +
    metadata and bump `last_seen_at`. Tokens are globally unique (FCM
    guarantees this), so a new owner means a device was handed over /
    reinstalled.
    """
    user_id = _user_uuid(current_user)
    existing = (
        db.query(UserDevice).filter(UserDevice.fcm_token == payload.fcm_token).first()
    )
    if existing is not None:
        existing.user_id = user_id
        existing.platform = payload.platform
        existing.device_label = payload.device_label
        existing.app_version = payload.app_version
        existing.last_seen_at = datetime.utcnow()
        db.commit()
        db.refresh(existing)
        return DeviceRead.model_validate(existing)

    device = UserDevice(
        user_id=user_id,
        fcm_token=payload.fcm_token,
        platform=payload.platform,
        device_label=payload.device_label,
        app_version=payload.app_version,
    )
    db.add(device)
    db.commit()
    db.refresh(device)
    return DeviceRead.model_validate(device)


@router.delete(
    "/devices/{fcm_token}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def unregister_device(
    fcm_token: str,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    user_id = _user_uuid(current_user)
    db.query(UserDevice).filter(
        and_(UserDevice.fcm_token == fcm_token, UserDevice.user_id == user_id)
    ).delete(synchronize_session=False)
    db.commit()
    return None
