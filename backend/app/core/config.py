
import os
from dotenv import load_dotenv

load_dotenv()


class Settings:
    # Application
    APP_NAME: str = os.getenv("APP_NAME", "NOVOX")
    APP_ENV: str = os.getenv("APP_ENV", "development")

    # Database
    DATABASE_URL: str = os.getenv("DATABASE_URL", "").strip()

    if APP_ENV.lower() == "production" and not DATABASE_URL:
        raise RuntimeError(
            "DATABASE_URL must be configured in production."
        )

    # Authentication / JWT
    JWT_SECRET_KEY: str = os.getenv("JWT_SECRET_KEY", "").strip()

    JWT_ALGORITHM: str = os.getenv("JWT_ALGORITHM", "HS256")

    ACCESS_TOKEN_EXPIRE_MINUTES: int = int(
        os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "60")
    )

    if APP_ENV.lower() == "production":
        if not JWT_SECRET_KEY:
            raise RuntimeError(
                "JWT_SECRET_KEY must be configured in production."
            )

        if JWT_SECRET_KEY == "change-this-secret":
            raise RuntimeError(
                "The default JWT secret is not allowed in production."
            )

    # CORS
    # Set this Railway variable to your actual Firebase Hosting origin:
    # CORS_ALLOW_ORIGIN_REGEX=^https://YOUR-SITE\.web\.app$
    CORS_ALLOW_ORIGIN_REGEX: str = os.getenv(
        "CORS_ALLOW_ORIGIN_REGEX",
        r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    )


settings = Settings()
