from typing import List, Optional, Union
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_name: str = "Sapar API"
    environment: str = "development"
    debug: bool = True
    api_v1_prefix: str = "/api/v1"

    secret_key: str = "sapar-super-secret-key-change-in-production-2026"
    access_token_expire_minutes: int = 60 * 24  # 1 day
    algorithm: str = "HS256"

    database_url: str = "sqlite:///./sapar.db"
    cors_origins: Union[List[str], str] = ["*"]

    # --- Платежная система Kaspi Pay ---
    # При указании реального KASPI_API_KEY и KASPI_MERCHANT_ID система
    # автоматически начинает обращаться к боевому API Kaspi Pay.
    kaspi_api_key: Optional[str] = None
    kaspi_merchant_id: Optional[str] = None
    kaspi_service_id: Optional[str] = None
    kaspi_api_url: str = "https://kaspi.kz/api/v1"
    kaspi_test_mode: bool = True
    kaspi_webhook_secret: Optional[str] = None

    # Другие провайдеры (Halyk Bank / Карта)
    halyk_client_id: Optional[str] = None
    halyk_client_secret: Optional[str] = None

    @field_validator("cors_origins", mode="before")
    @classmethod
    def assemble_cors_origins(cls, v: Union[str, List[str]]) -> List[str]:
        if isinstance(v, str) and not v.startswith("["):
            return [i.strip() for i in v.split(",") if i.strip()]
        elif isinstance(v, list):
            return v
        return ["*"]


settings = Settings()
