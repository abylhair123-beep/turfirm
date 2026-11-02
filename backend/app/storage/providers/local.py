import logging
import os

from app.core.config import settings
from app.storage.providers.base import BaseStorageProvider, UploadResult

logger = logging.getLogger(__name__)


class LocalStorageProvider(BaseStorageProvider):
    """Хранит файлы на диске сервера в папке upload_dir.

    Файлы отдаются статикой по пути /uploads/... (монтируется в main.py).
    Возвращает относительный URL, который роутер дополняет до абсолютного.
    """

    backend = "local"

    @property
    def base_dir(self) -> str:
        return settings.upload_dir

    def _ensure_dir(self, path: str) -> None:
        os.makedirs(path, exist_ok=True)

    def save(self, *, data: bytes, filename: str, content_type: str) -> UploadResult:
        # filename уже содержит подпапку, напр. "tours/ab12cd34.jpg"
        full_path = os.path.join(self.base_dir, filename)
        self._ensure_dir(os.path.dirname(full_path))

        with open(full_path, "wb") as f:
            f.write(data)

        logger.info("[Local storage] Файл сохранён: %s (%d байт)", full_path, len(data))
        # URL относительный — роутер добавит схему и хост
        rel_url = "/" + settings.upload_dir.strip("/") + "/" + filename.replace("\\", "/")
        return UploadResult(url=rel_url, key=filename, backend=self.backend)

    def delete(self, key: str) -> bool:
        full_path = os.path.join(self.base_dir, key)
        try:
            if os.path.isfile(full_path):
                os.remove(full_path)
                logger.info("[Local storage] Файл удалён: %s", full_path)
                return True
            return False
        except OSError as e:
            logger.error("[Local storage] Ошибка удаления %s: %s", full_path, e)
            return False
