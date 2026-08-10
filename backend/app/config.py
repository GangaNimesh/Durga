import warnings
from functools import lru_cache

from pydantic_settings import BaseSettings

_DEV_SECRET_KEY = "dev-only-insecure-secret-change-me"


class Settings(BaseSettings):
    ENV: str = "development"
    DATABASE_URL: str = "sqlite:///./durga.db"
    SECRET_KEY: str = _DEV_SECRET_KEY
    CORS_ORIGINS: str = "*"
    UPLOAD_DIR: str = "uploads"
    MAX_UPLOAD_BYTES: int = 25 * 1024 * 1024
    FCM_SERVER_KEY: str = ""

    # JWT config
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24  # 24 hours
    ALGORITHM: str = "HS256"

    model_config = {"env_file": ".env", "extra": "ignore"}

    @property
    def cors_origin_list(self) -> list[str]:
        if self.CORS_ORIGINS.strip() == "*":
            return ["*"]
        return [origin.strip() for origin in self.CORS_ORIGINS.split(",") if origin.strip()]

    @property
    def is_sqlite(self) -> bool:
        return self.DATABASE_URL.startswith("sqlite")


@lru_cache()
def get_settings() -> Settings:
    settings = Settings()

    # FIX: SECRET_KEY had no default -> app crashed at import time on a fresh
    # clone with no .env. Now it boots with a dev default, but that default
    # must never reach production silently.
    if settings.SECRET_KEY == _DEV_SECRET_KEY:
        if settings.ENV == "production":
            raise RuntimeError(
                "SECRET_KEY is set to the insecure development default while "
                "ENV=production. Generate one with: "
                "python -c \"import secrets; print(secrets.token_urlsafe(64))\" "
                "and set it via the SECRET_KEY environment variable."
            )
        warnings.warn(
            "Using the insecure default SECRET_KEY. Fine for local development, "
            "but set a real one before deploying. Generate one with: "
            "python -c \"import secrets; print(secrets.token_urlsafe(64))\"",
            stacklevel=2,
        )

    return settings
