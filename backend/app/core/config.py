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

    # --- Уведомления о бронированиях ---
    # Telegram-бот для уведомлений турагентствам.
    # Получите токен у @BotFather и укажите TELEGRAM_BOT_TOKEN.
    # TELEGRAM_CHAT_ID — глобальный чат по умолчанию (если у агентства не задан свой).
    # Пока токен не указан, уведомления просто пишутся в лог (dev-режим).
    telegram_bot_token: Optional[str] = None
    telegram_chat_id: Optional[str] = None
    telegram_api_url: str = "https://api.telegram.org"

    # SMTP для писем клиентам. Если не настроен — письма пишутся в лог (dev-режим).
    smtp_host: Optional[str] = None
    smtp_port: int = 587
    smtp_user: Optional[str] = None
    smtp_password: Optional[str] = None
    smtp_from: Optional[str] = None  # Адрес отправителя; по умолчанию = smtp_user
    smtp_from_name: str = "Sapar"
    smtp_use_tls: bool = True

    # Публичное название сервиса для текстов уведомлений
    public_app_name: str = "Sapar"

    # --- Хранилище медиа (фото туров/отелей) ---
    # storage_backend: "local" (файлы на диске сервера) или "s3" (S3/MinIO).
    storage_backend: str = "local"
    upload_dir: str = "uploads"          # Папка для локальных файлов
    max_upload_mb: int = 5               # Максимальный размер файла, МБ
    public_base_url: Optional[str] = None  # Напр. http://localhost:8000; если None — берётся из запроса

    # S3 / MinIO (используется только при storage_backend="s3")
    s3_endpoint_url: Optional[str] = None  # MinIO: http://localhost:9000; AWS — оставить пустым
    s3_access_key: Optional[str] = None
    s3_secret_key: Optional[str] = None
    s3_bucket: str = "sapar-media"
    s3_region: str = "us-east-1"
    s3_public_url: Optional[str] = None    # Базовый URL для отдачи файлов (CDN/публичный MinIO)
    s3_use_ssl: bool = True

    @field_validator("cors_origins", mode="before")
    @classmethod
    def assemble_cors_origins(cls, v: Union[str, List[str]]) -> List[str]:
        if isinstance(v, str) and not v.startswith("["):
            return [i.strip() for i in v.split(",") if i.strip()]
        elif isinstance(v, list):
            return v
        return ["*"]


settings = Settings()
