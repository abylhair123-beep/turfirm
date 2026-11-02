from typing import Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.config import settings
from app.database import get_db
from app.dependencies import get_current_admin
from app.auth.models import User
from app.notifications.providers import email_provider, telegram_provider

router = APIRouter(prefix="/notifications", tags=["Уведомления"])


@router.get("/config-status")
def get_notifications_config_status():
    """Текущее состояние каналов уведомлений (Telegram / Email).

    Показывает, настроена ли реальная отправка или канал работает в dev-режиме (лог).
    """
    return {
        "telegram": {
            "channel": "telegram",
            "isConfigured": telegram_provider.is_configured,
            "mode": "live" if telegram_provider.is_configured else "test_log",
            "defaultChatId": settings.telegram_chat_id or "Не задан",
            "hint": "Укажите TELEGRAM_BOT_TOKEN и TELEGRAM_CHAT_ID в .env для реальной отправки",
        },
        "email": {
            "channel": "email",
            "isConfigured": email_provider.is_configured,
            "mode": "live" if email_provider.is_configured else "test_log",
            "smtpHost": settings.smtp_host or "Не задан",
            "hint": "Укажите SMTP_HOST, SMTP_USER, SMTP_PASSWORD в .env для реальной отправки",
        },
    }


class TestNotificationRequest(BaseModel):
    channel: str = Field(description="Канал: 'telegram' или 'email'")
    to: Optional[str] = Field(default=None, description="Chat ID (Telegram) или email (Email)")
    message: str = Field(default="Тестовое уведомление Sapar ✅")


@router.post("/test")
def send_test_notification(
    req: TestNotificationRequest,
    current_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """Отправить тестовое уведомление по выбранному каналу (только для админа)."""
    channel = req.channel.lower().strip()
    if channel == "telegram":
        result = telegram_provider.send(to=req.to, message=req.message)
    elif channel == "email":
        result = email_provider.send(
            to=req.to,
            subject="Тестовое уведомление Sapar",
            message=req.message,
        )
    else:
        return {"success": False, "detail": f"Неизвестный канал: {req.channel}"}

    return {
        "success": result.success,
        "channel": result.channel,
        "mode": result.mode,
        "detail": result.detail,
    }
