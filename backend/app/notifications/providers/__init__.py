from app.notifications.providers.base import BaseNotificationProvider, NotificationResult
from app.notifications.providers.email import EmailNotificationProvider
from app.notifications.providers.telegram import TelegramNotificationProvider

# Единые экземпляры провайдеров для переиспользования
telegram_provider = TelegramNotificationProvider()
email_provider = EmailNotificationProvider()

__all__ = [
    "BaseNotificationProvider",
    "NotificationResult",
    "EmailNotificationProvider",
    "TelegramNotificationProvider",
    "telegram_provider",
    "email_provider",
]
