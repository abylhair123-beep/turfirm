import logging
from typing import Any, Optional

import httpx

from app.core.config import settings
from app.notifications.providers.base import BaseNotificationProvider, NotificationResult

logger = logging.getLogger(__name__)


class TelegramNotificationProvider(BaseNotificationProvider):
    """Отправка уведомлений турагентству через Telegram Bot API.

    Если TELEGRAM_BOT_TOKEN не задан в .env, провайдер работает в dev-режиме:
    сообщение просто пишется в лог, бронирование не прерывается.
    """

    channel = "telegram"

    @property
    def is_configured(self) -> bool:
        return bool(settings.telegram_bot_token)

    def resolve_chat_id(self, chat_id: Optional[str] = None) -> Optional[str]:
        """Чат агентства, иначе — глобальный TELEGRAM_CHAT_ID по умолчанию."""
        return chat_id or settings.telegram_chat_id

    def send(
        self,
        *,
        to: Optional[str] = None,
        subject: str = "",
        message: str,
        html: Optional[str] = None,
        **kwargs: Any,
    ) -> NotificationResult:
        chat_id = self.resolve_chat_id(to)

        if not self.is_configured or not chat_id:
            logger.info(
                "[Telegram dev] Уведомление не отправлено (бот не настроен или нет chat_id=%s):\n%s",
                chat_id,
                message,
            )
            return NotificationResult(
                success=False,
                channel=self.channel,
                mode="test_log",
                detail="TELEGRAM_BOT_TOKEN или chat_id не заданы — сообщение записано в лог",
            )

        url = f"{settings.telegram_api_url.rstrip('/')}/bot{settings.telegram_bot_token}/sendMessage"
        payload = {
            "chat_id": chat_id,
            "text": message,
            "parse_mode": "HTML",
            "disable_web_page_preview": True,
        }

        try:
            with httpx.Client(timeout=10.0) as client:
                res = client.post(url, json=payload)
                res.raise_for_status()
                data = res.json()
            logger.info("[Telegram] Уведомление отправлено в чат %s", chat_id)
            return NotificationResult(
                success=True,
                channel=self.channel,
                detail="sent",
                raw_response=data,
            )
        except Exception as e:
            logger.error("[Telegram] Ошибка отправки в чат %s: %s", chat_id, e, exc_info=True)
            return NotificationResult(
                success=False,
                channel=self.channel,
                detail=str(e),
            )
