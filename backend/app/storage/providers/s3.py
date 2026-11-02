import logging

from app.core.config import settings
from app.storage.providers.base import BaseStorageProvider, UploadResult

logger = logging.getLogger(__name__)


class S3StorageProvider(BaseStorageProvider):
    """Хранилище на S3-совместимом сервисе (AWS S3 или MinIO).

    Требует boto3 (pip install boto3). Настраивается через S3_* в .env.
    Для MinIO укажите S3_ENDPOINT_URL (напр. http://localhost:9000).
    """

    backend = "s3"

    @property
    def is_configured(self) -> bool:
        return bool(settings.s3_access_key and settings.s3_secret_key and settings.s3_bucket)

    def _client(self):
        try:
            import boto3  # Ленивый импорт: нужен только в режиме s3
        except ImportError as e:
            raise RuntimeError(
                "Для режима S3 нужен boto3. Установите: pip install boto3"
            ) from e

        return boto3.client(
            "s3",
            endpoint_url=settings.s3_endpoint_url,  # None для AWS, URL для MinIO
            aws_access_key_id=settings.s3_access_key,
            aws_secret_access_key=settings.s3_secret_key,
            region_name=settings.s3_region,
            use_ssl=settings.s3_use_ssl,
        )

    def _public_url(self, key: str) -> str:
        if settings.s3_public_url:
            base = settings.s3_public_url.rstrip("/")
            return f"{base}/{key}"
        if settings.s3_endpoint_url:
            base = settings.s3_endpoint_url.rstrip("/")
            return f"{base}/{settings.s3_bucket}/{key}"
        # AWS S3 стандартный публичный URL
        return f"https://{settings.s3_bucket}.s3.{settings.s3_region}.amazonaws.com/{key}"

    def save(self, *, data: bytes, filename: str, content_type: str) -> UploadResult:
        client = self._client()
        client.put_object(
            Bucket=settings.s3_bucket,
            Key=filename,
            Body=data,
            ContentType=content_type,
            ACL="public-read",
        )
        url = self._public_url(filename)
        logger.info("[S3 storage] Файл загружен: %s", url)
        return UploadResult(url=url, key=filename, backend=self.backend)

    def delete(self, key: str) -> bool:
        try:
            self._client().delete_object(Bucket=settings.s3_bucket, Key=key)
            logger.info("[S3 storage] Файл удалён: %s", key)
            return True
        except Exception as e:
            logger.error("[S3 storage] Ошибка удаления %s: %s", key, e)
            return False
