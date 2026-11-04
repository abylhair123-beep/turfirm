import logging
from typing import Optional
from slowapi import Limiter
from slowapi.util import get_remote_address
from starlette.requests import Request

from app.core.config import settings

logger = logging.getLogger("app.limiter")


def get_client_ip(request: Request) -> str:
    """Извлекает реальный IP клиента с учётом обратных прокси (Nginx / Cloudflare)."""
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()
    real_ip = request.headers.get("X-Real-IP")
    if real_ip:
        return real_ip.strip()
    return get_remote_address(request)


def create_limiter() -> Limiter:
    """Создаёт настроенный RateLimiter с поддержкой Redis и in-memory fallback."""
    storage_uri = settings.rate_limit_storage_uri
    if not storage_uri:
        if settings.redis_enabled:
            storage_uri = settings.redis_url
        else:
            storage_uri = "memory://"

    try:
        lim = Limiter(
            key_func=get_client_ip,
            enabled=settings.rate_limit_enabled,
            storage_uri=storage_uri,
            in_memory_fallback=["10/second"],
            strategy="fixed-window",
            headers_enabled=False,
        )
        return lim
    except Exception as e:
        logger.warning(f"Ошибка подключения хранилища RateLimiter ({storage_uri}), fallback на memory://: {e}")
        return Limiter(
            key_func=get_client_ip,
            enabled=settings.rate_limit_enabled,
            storage_uri="memory://",
            strategy="fixed-window",
            headers_enabled=False,
        )


limiter = create_limiter()
