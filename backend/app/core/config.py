
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    DATABASE_URL: str
    SECRET_KEY: str
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    ADMIN_SIGNUP_KEY: str
    PRINTER_ENCRYPTION_KEY: str = ""

    OCTOPRINT_DEV_API_KEY: str = ""

    SMTP_HOST: str = "sandbox.smtp.mailtrap.io"
    SMTP_PORT: int = 2525
    SMTP_USER: str = ""
    SMTP_PASS: str = ""
    EMAIL_FROM: str = "noreply@3dp.com"
    APP_BASE_URL: str = "http://localhost:3000"

    SLICER_PRUSA_PATH: str = "/usr/bin/prusa-slicer"
    STL_UPLOAD_DIR: str = "/app/uploads/stl"
    GCODE_UPLOAD_DIR: str = "/app/uploads/gcode"
    SLICER_TIMEOUT_SECONDS: int = 600
    SLICER_STDERR_TAIL_BYTES: int = 65536
    REDIS_URL: str = "redis://redis:6379/0"
    SLICING_WORKER_CONCURRENCY: int = 2
    IN_APP_SLICING_ENABLED: bool = True
    SLICING_RUNNING_RECOVERY_SECONDS: int = 1800  # 30 min: orphan running rows reset on api startup

    STATUS_POLL_INTERVAL_SECONDS: int = 30
    STATUS_POLL_STALE_SECONDS: int = 300  # 5 min: watchdog marks failed if no successful poll
    STATUS_POLL_COMPLETION_THRESHOLD: float = 0.99
    STATUS_POLL_ENABLED: bool = True

    # Anomaly detection (Sprint 4 / US-21)
    ANOMALY_DETECTION_ENABLED: bool = True
    ANOMALY_TEMP_DRIFT_C: float = 15.0
    ANOMALY_TEMP_DRIFT_POLLS: int = 3
    ANOMALY_PROGRESS_STALL_MINUTES: int = 20
    ANOMALY_DURATION_OVERRUN_FACTOR: float = 1.3

    # WebSockets (PRD §6.4)
    WEBSOCKETS_ENABLED: bool = True
    WS_PING_INTERVAL_S: int = 30
    WS_PONG_TIMEOUT_S: int = 90
    WS_SEND_QUEUE_MAX: int = 1000
    WS_BACKPRESSURE_GRACE_S: int = 30
    WS_LAST_EVENT_TTL_S: int = 86400  # 24h, refreshed on each publish
    WS_MAX_TOPICS_PER_CONNECTION: int = 100
    WS_MAX_SOCKETS_PER_USER: int = 5
    PRINTER_POLL_INTERVAL_S: int = 5

    # FCM push (Phase 3)
    # Master switch — when false, NotificationService still persists + publishes
    # WS, but never calls firebase-admin (useful in tests / local dev without
    # a Firebase project).
    FCM_ENABLED: bool = False
    # Absolute path to the Firebase service-account JSON key. Required when
    # FCM_ENABLED is true. Mount the file as a secret in production.
    FCM_CREDENTIALS_PATH: str = ""
    # Android channel ids — must match what the Flutter client registers
    # in FcmService._setupLocalChannels. Mapping is by severity (Phase 4).
    FCM_DEFAULT_ANDROID_CHANNEL: str = "notifications_default"
    FCM_ERRORS_ANDROID_CHANNEL: str = "notifications_errors"
    FCM_WARNINGS_ANDROID_CHANNEL: str = "notifications_warnings"
    FCM_SUCCESS_ANDROID_CHANNEL: str = "notifications_success"

    class Config:
        env_file = ".env"


settings = Settings()