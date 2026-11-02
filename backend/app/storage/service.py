"""Сервис загрузки медиа: валидация файла и сохранение через активный провайдер."""
import logging
import os
import uuid

from app.core.config import settings
from app.storage.providers import UploadResult, get_storage_provider

logger = logging.getLogger(__name__)

# Разрешённые типы изображений: MIME -> расширение
ALLOWED_IMAGE_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "image/gif": ".gif",
}

# Разрешённые папки для раскладки файлов
ALLOWED_FOLDERS = {"tours", "agencies", "misc"}


class UploadValidationError(Exception):
    """Ошибка валидации загружаемого файла (неверный тип или размер)."""


def _resolve_extension(content_type: str, filename: str) -> str:
    """Расширение файла по MIME-типу, с запасным вариантом из имени."""
    ext = ALLOWED_IMAGE_TYPES.get(content_type)
    if ext:
        return ext
    _, dot_ext = os.path.splitext(filename or "")
    return dot_ext.lower() or ".bin"


def validate_image(*, content_type: str, size_bytes: int) -> None:
    """Проверяет тип и размер изображения. Бросает UploadValidationError."""
    if content_type not in ALLOWED_IMAGE_TYPES:
        allowed = ", ".join(sorted(ALLOWED_IMAGE_TYPES))
        raise UploadValidationError(
            f"Недопустимый тип файла '{content_type}'. Разрешены: {allowed}"
        )

    max_bytes = settings.max_upload_mb * 1024 * 1024
    if size_bytes > max_bytes:
        raise UploadValidationError(
            f"Файл слишком большой ({size_bytes // 1024} КБ). "
            f"Максимум — {settings.max_upload_mb} МБ"
        )
    if size_bytes == 0:
        raise UploadValidationError("Файл пустой")


def save_image(*, data: bytes, content_type: str, filename: str, folder: str = "misc") -> UploadResult:
    """Валидирует и сохраняет изображение, возвращает UploadResult."""
    validate_image(content_type=content_type, size_bytes=len(data))

    safe_folder = folder if folder in ALLOWED_FOLDERS else "misc"
    ext = _resolve_extension(content_type, filename)
    key = f"{safe_folder}/{uuid.uuid4().hex}{ext}"

    provider = get_storage_provider()
    result = provider.save(data=data, filename=key, content_type=content_type)
    logger.info("Загружен файл %s через backend=%s", result.key, result.backend)
    return result
