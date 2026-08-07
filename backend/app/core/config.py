from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import List


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # App
    APP_NAME: str = "Healthy Home Foods"
    APP_ENV: str = "development"
    DEBUG: bool = True
    SECRET_KEY: str = "dev-secret-key-123456789-change-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    API_V1_PREFIX: str = "/api/v1"
    ALLOWED_ORIGINS: List[str] = ["http://localhost:3000", "http://localhost:5173", "http://localhost:5174", "http://127.0.0.1:5173", "http://127.0.0.1:5174"]

    # Database
    DATABASE_URL: str = "sqlite+aiosqlite:///healthy_home.db"
    SYNC_DATABASE_URL: str = "sqlite:///healthy_home.db"

    # Redis / Celery
    REDIS_URL: str = "redis://localhost:6379/0"
    CELERY_BROKER_URL: str = "redis://localhost:6379/1"
    CELERY_RESULT_BACKEND: str = "redis://localhost:6379/2"

    # OTP
    OTP_PROVIDER: str = "msg91"
    MSG91_AUTH_KEY: str = ""
    MSG91_TEMPLATE_ID: str = ""
    MSG91_SENDER_ID: str = "HHFOTP"
    OTP_EXPIRY_MINUTES: int = 5
    OTP_MAX_ATTEMPTS: int = 3

    # Email
    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USERNAME: str = ""
    SMTP_PASSWORD: str = ""
    EMAIL_FROM: str = "noreply@healthyhomefoods.com"
    EMAIL_FROM_NAME: str = "Healthy Home Foods"

    # Payments
    RAZORPAY_KEY_ID: str = ""
    RAZORPAY_KEY_SECRET: str = ""
    RAZORPAY_WEBHOOK_SECRET: str = ""

    # Maps
    GOOGLE_MAPS_API_KEY: str = ""

    # Firebase
    FIREBASE_CREDENTIALS_PATH: str = "./firebase-credentials.json"

    # Defaults (overridden by admin_settings table)
    DEFAULT_FREE_DELIVERY_RADIUS_KM: float = 5.0
    DEFAULT_DELIVERY_CHARGE_PER_KM: float = 10.0
    DEFAULT_TAX_PERCENTAGE: float = 0.0

    # Upload
    UPLOAD_DIR: str = "./uploads"
    MAX_UPLOAD_SIZE_MB: int = 5


import socket

def _normalize_db_url(url: str) -> str:
    if "@db:5432" in url:
        try:
            socket.gethostbyname("db")
        except socket.gaierror:
            return url.replace("@db:5432", "@127.0.0.1:5432")
    return url

settings = Settings()
settings.DATABASE_URL = _normalize_db_url(settings.DATABASE_URL)
settings.SYNC_DATABASE_URL = _normalize_db_url(settings.SYNC_DATABASE_URL)
