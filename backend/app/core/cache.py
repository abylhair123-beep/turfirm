import hashlib
import json
import logging
from typing import Any, Optional
import redis

from app.core.config import settings

logger = logging.getLogger("app.cache")


class CacheManager:
    """Менеджер кэширования на базе Redis с отказоустойчивостью (graceful fallback).

    Если Redis недоступен или выключен, запросы прозрачно идут в базу данных
    без возникновения ошибок у клиента.
    """

    def __init__(self):
        self._client: Optional[redis.Redis] = None
        self._connected: Optional[bool] = None

    @property
    def client(self) -> Optional[redis.Redis]:
        if not settings.redis_enabled:
            return None
        if self._client is None:
            try:
                self._client = redis.Redis.from_url(
                    settings.redis_url,
                    decode_responses=True,
                    socket_connect_timeout=1.5,
                    socket_timeout=1.5,
                )
            except Exception as e:
                logger.warning(f"Не удалось инициализировать клиент Redis: {e}")
                self._client = None
        return self._client

    def ping(self) -> bool:
        """Проверка доступности сервера Redis."""
        c = self.client
        if not c:
            return False
        try:
            return bool(c.ping())
        except Exception:
            return False

    def get(self, key: str) -> Optional[Any]:
        """Получить значение по ключу (десериализует JSON)."""
        c = self.client
        if not c:
            return None
        try:
            raw = c.get(key)
            if raw is not None:
                return json.loads(raw)
        except Exception as e:
            logger.debug(f"Ошибка чтения кэша Redis ({key}): {e}")
        return None

    def set(self, key: str, value: Any, ttl_seconds: int = 600) -> bool:
        """Сохранить значение с временем жизни (TTL в секундах)."""
        c = self.client
        if not c:
            return False
        try:
            payload = json.dumps(value, ensure_ascii=False, default=str)
            return bool(c.set(name=key, value=payload, ex=ttl_seconds))
        except Exception as e:
            logger.debug(f"Ошибка записи в кэш Redis ({key}): {e}")
            return False

    def delete(self, key: str) -> bool:
        """Удалить конкретный ключ из кэша."""
        c = self.client
        if not c:
            return False
        try:
            return bool(c.delete(key))
        except Exception as e:
            logger.debug(f"Ошибка удаления ключа кэша ({key}): {e}")
            return False

    def delete_pattern(self, pattern: str) -> int:
        """Удалить все ключи по маске (например, 'sapar:cache:tours:*')."""
        c = self.client
        if not c:
            return 0
        try:
            cursor = 0
            deleted_count = 0
            while True:
                cursor, keys = c.scan(cursor=cursor, match=pattern, count=100)
                if keys:
                    deleted_count += c.delete(*keys)
                if cursor == 0:
                    break
            return deleted_count
        except Exception as e:
            logger.debug(f"Ошибка инвалидации кэша по маске ({pattern}): {e}")
            return 0

    @staticmethod
    def generate_key(prefix: str, **kwargs) -> str:
        """Генерация детерминированного ключа кэша на основе параметров запроса."""
        clean_items = sorted((k, str(v)) for k, v in kwargs.items() if v is not None)
        raw_repr = "&".join(f"{k}={v}" for k, v in clean_items)
        if not raw_repr:
            return f"sapar:cache:{prefix}:default"
        digest = hashlib.md5(raw_repr.encode("utf-8")).hexdigest()[:12]
        return f"sapar:cache:{prefix}:{digest}"


cache = CacheManager()
