from app.core.config import settings
from app.storage.providers.base import BaseStorageProvider, UploadResult
from app.storage.providers.local import LocalStorageProvider
from app.storage.providers.s3 import S3StorageProvider

_local_provider = LocalStorageProvider()
_s3_provider = S3StorageProvider()


def get_storage_provider() -> BaseStorageProvider:
    """Возвращает активный провайдер согласно settings.storage_backend."""
    if settings.storage_backend.lower().strip() == "s3":
        return _s3_provider
    return _local_provider


__all__ = [
    "BaseStorageProvider",
    "UploadResult",
    "LocalStorageProvider",
    "S3StorageProvider",
    "get_storage_provider",
]
