"""FCM push delivery via firebase-admin.

Lazy initialization — the Firebase app is created on first send so the
backend boots fine in environments without credentials (e.g. CI, local
dev with `FCM_ENABLED=false`).

Public surface:
- `send_to_user(db, user_id, ...)` — fan out a notification to every
  registered device for that user. Invalid / unregistered tokens are
  pruned from `user_devices` automatically.
"""

from __future__ import annotations

import logging
import threading
from typing import Any, Optional
from uuid import UUID

from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.user_device import UserDevice

logger = logging.getLogger(__name__)

_init_lock = threading.Lock()
_initialized = False
_messaging = None  # firebase_admin.messaging module (lazy import)


def _ensure_initialized() -> bool:
    """Initialize the Firebase app once. Returns True if FCM is usable."""
    global _initialized, _messaging

    if not settings.FCM_ENABLED:
        return False
    if _initialized:
        return _messaging is not None

    with _init_lock:
        if _initialized:
            return _messaging is not None
        try:
            import firebase_admin
            from firebase_admin import credentials, messaging as fb_messaging

            if not settings.FCM_CREDENTIALS_PATH:
                logger.error("FCM_ENABLED=true but FCM_CREDENTIALS_PATH is empty")
                _initialized = True
                return False

            if not firebase_admin._apps:
                cred = credentials.Certificate(settings.FCM_CREDENTIALS_PATH)
                firebase_admin.initialize_app(cred)

            _messaging = fb_messaging
            _initialized = True
            logger.info("firebase-admin initialized")
            return True
        except Exception:
            logger.exception("firebase-admin init failed; FCM disabled at runtime")
            _initialized = True
            _messaging = None
            return False


# Token errors that mean "this token will never deliver again" — we
# delete those rows so the table doesn't grow indefinitely.
_DEAD_TOKEN_ERRORS = {
    "registration-token-not-registered",
    "invalid-registration-token",
    "invalid-argument",
}


def _channel_for_severity(severity: str) -> str:
    """Map severity → Android notification channel id.

    Separate channels let the OS apply different importance + sound +
    vibration. The Flutter client registers all four in
    `FcmService._setupLocalChannels`.
    """
    if severity == "error":
        return settings.FCM_ERRORS_ANDROID_CHANNEL
    if severity == "warning":
        return settings.FCM_WARNINGS_ANDROID_CHANNEL
    if severity == "success":
        return settings.FCM_SUCCESS_ANDROID_CHANNEL
    return settings.FCM_DEFAULT_ANDROID_CHANNEL


def send_to_user(
    db: Session,
    *,
    user_id: UUID,
    title: str,
    body: Optional[str],
    data: Optional[dict[str, Any]] = None,
    collapse_key: Optional[str] = None,
    severity: str = "info",
) -> int:
    """Send a push notification to all of user's registered devices.

    Returns the number of successful sends. Best-effort: never raises.
    """
    if not _ensure_initialized():
        return 0

    devices: list[UserDevice] = (
        db.query(UserDevice).filter(UserDevice.user_id == user_id).all()
    )
    if not devices:
        return 0

    assert _messaging is not None

    # FCM `data` payload must be all strings. Flatten + stringify for cross-
    # platform safety (Android/iOS background handlers expect strings).
    str_data: dict[str, str] = {
        "category": (data or {}).get("category", ""),
        "type": (data or {}).get("type", ""),
        "severity": severity,
    }
    if data:
        for k, v in data.items():
            if v is None:
                continue
            str_data[k] = str(v)

    android_priority = "high" if severity in ("warning", "error") else "normal"
    channel_id = _channel_for_severity(severity)

    success = 0
    for device in devices:
        try:
            android_cfg = _messaging.AndroidConfig(
                priority=android_priority,
                collapse_key=collapse_key,
                notification=_messaging.AndroidNotification(
                    channel_id=channel_id,
                    tag=collapse_key,  # replaces prior notif with same tag
                ),
            )
            apns_headers: dict[str, str] = {
                "apns-priority": "10" if severity in ("warning", "error") else "5",
                "apns-push-type": "alert",
            }
            if collapse_key:
                apns_headers["apns-collapse-id"] = collapse_key
            apns_cfg = _messaging.APNSConfig(headers=apns_headers)

            message = _messaging.Message(
                token=device.fcm_token,
                notification=_messaging.Notification(title=title, body=body or ""),
                data=str_data,
                android=android_cfg,
                apns=apns_cfg,
            )
            _messaging.send(message)
            success += 1
        except Exception as exc:
            err_code = getattr(exc, "code", "") or ""
            if err_code in _DEAD_TOKEN_ERRORS:
                logger.info(
                    "pruning dead FCM token user=%s token=%s err=%s",
                    user_id,
                    device.fcm_token[:12] + "…",
                    err_code,
                )
                try:
                    db.delete(device)
                    db.flush()
                except Exception:
                    logger.warning("failed to prune dead token", exc_info=True)
            else:
                logger.warning(
                    "fcm send failed user=%s err=%s",
                    user_id,
                    err_code or repr(exc),
                )

    return success
