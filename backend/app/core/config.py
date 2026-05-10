
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

    class Config:
        env_file = ".env"


settings = Settings()