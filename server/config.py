"""Configuration for the DSCVR API server."""
import os


class Config:
    """Base config — values come from environment variables."""

    # Firebase
    FIREBASE_PROJECT_ID = os.getenv("FIREBASE_PROJECT_ID", "dscvr-9d362")

    # Google Pay
    GOOGLE_PAY_MERCHANT_ID = os.getenv("GOOGLE_PAY_MERCHANT_ID", "")
    GOOGLE_PAY_MERCHANT_NAME = os.getenv("GOOGLE_PAY_MERCHANT_NAME", "DSCVR Research")

    # CORS origins
    ALLOWED_ORIGINS = [
        r"https://dscvr-9d362\.web\.app",
        r"https://dscvr-9d362\.firebaseapp\.com",
        r"https://dscvr\.askpinda\.com",
        r"https://(www\.)?askpinda\.com",
        r"http://localhost(:\d+)?",
        r"http://127\.0\.0\.1(:\d+)?",
    ]

    # Rate limiting defaults
    RATE_LIMIT_PER_MINUTE = int(os.getenv("RATE_LIMIT_PER_MINUTE", "30"))
    RATE_LIMIT_PER_HOUR = int(os.getenv("RATE_LIMIT_PER_HOUR", "300"))

    # Server
    PORT = int(os.getenv("PORT", "8080"))
    DEBUG = os.getenv("FLASK_DEBUG", "false").lower() == "true"


class DevConfig(Config):
    DEBUG = True


class ProdConfig(Config):
    DEBUG = False
