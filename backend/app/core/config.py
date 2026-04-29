
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    DATABASE_URL: str
    SECRET_KEY: str
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    ADMIN_SIGNUP_KEY: str
    PRINTER_ENCRYPTION_KEY: str

    SMTP_HOST: str = "sandbox.smtp.mailtrap.io"
    SMTP_PORT: int = 2525
    SMTP_USER: str = ""
    SMTP_PASS: str = ""
    SMTP_FROM: str = "noreply@3dp.com"
    APP_BASE_URL: str = "http://localhost:3000"

    class Config:
        env_file = ".env"


settings = Settings()