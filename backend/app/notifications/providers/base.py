from dataclasses import dataclass, field
from typing import Any, Dict, Optional


@dataclass
class NotificationResult:
    """Результат отправки одного уведомления по конкретному каналу."""

    success: bool
    channel: str
    detail: str = ""
    mode: str = "live"  # "live" — реальная отправка, "test_log" — записано в лог (dev)
    raw_response: Dict[str, Any] = field(default_factory=dict)


class BaseNotificationProvider:
    """Базовый класс канала уведомлений (Telegram, Email, в будущем SMS)."""

    channel: str = "base"

    @property
    def is_configured(self) -> bool:
        """Заданы ли боевые ключи/доступы для этого канала."""
        return False

    def send(
        self,
        *,
        to: Optional[str],
        subject: str = "",
        message: str,
        html: Optional[str] = None,
        **kwargs: Any,
    ) -> NotificationResult:
        raise NotImplementedError
