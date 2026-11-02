import logging
import smtplib
from email.message import EmailMessage
from typing import Any, Optional

from app.core.config import settings
from app.notifications.providers.base import BaseNotificationProvider, NotificationResult

logger = logging.getLogger(__name__)


class EmailNotificationProvider(BaseNotificationProvider):
    """Отправка писем клиентам по SMTP (стандартная библиотека smtplib).

    Если SMTP_HOST/SMTP_USER/SMTP_PASSWORD не заданы, провайдер работает
    в dev-режиме: письмо пишется в лог, бронирование не прерывается.
    """

    channel = "email"

    @property
    def is_configured(self) -> bool:
        return bool(settings.smtp_host and settings.smtp_user and settings.smtp_password)

    def send(
        self,
        *,
        to: Optional[str],
        subject: str = "",
        message: str,
        html: Optional[str] = None,
        **kwargs: Any,
    ) -> NotificationResult:
        if not to:
            return NotificationResult(
                success=False,
                channel=self.channel,
                detail="Не указан email получателя",
            )

        if not self.is_configured:
            logger.info(
                "[Email dev] Письмо '%s' для %s не отправлено (SMTP не настроен):\n%s",
                subject,
                to,
                message,
            )
            return NotificationResult(
                success=False,
                channel=self.channel,
                mode="test_log",
                detail="SMTP не настроен — письмо записано в лог",
            )

        from_addr = settings.smtp_from or settings.smtp_user
        msg = EmailMessage()
        msg["Subject"] = subject
        msg["From"] = f"{settings.smtp_from_name} <{from_addr}>"
        msg["To"] = to
        msg.set_content(message)
        if html:
            msg.add_alternative(html, subtype="html")

        try:
            with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=15) as server:
                if settings.smtp_use_tls:
                    server.starttls()
                server.login(settings.smtp_user, settings.smtp_password)
                server.send_message(msg)
            logger.info("[Email] Письмо '%s' отправлено на %s", subject, to)
            return NotificationResult(success=True, channel=self.channel, detail="sent")
        except Exception as e:
            logger.error("[Email] Ошибка отправки на %s: %s", to, e, exc_info=True)
            return NotificationResult(success=False, channel=self.channel, detail=str(e))
