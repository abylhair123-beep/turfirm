from dataclasses import dataclass


@dataclass
class UploadResult:
    """Результат сохранения файла в хранилище."""

    url: str  # Абсолютный URL (S3) или путь вида "/uploads/..." (local, дополняется роутером)
    key: str  # Ключ/путь файла внутри хранилища (для удаления)
    backend: str


class BaseStorageProvider:
    """Базовый класс хранилища медиа (local, S3/MinIO)."""

    backend: str = "base"

    def save(self, *, data: bytes, filename: str, content_type: str) -> UploadResult:
        raise NotImplementedError

    def delete(self, key: str) -> bool:
        raise NotImplementedError
