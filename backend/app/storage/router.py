import logging

from fastapi import APIRouter, Depends, File, HTTPException, Query, Request, UploadFile, status

from app.auth.models import User
from app.core.config import settings
from app.dependencies import get_current_agency_user
from app.storage.providers import get_storage_provider
from app.storage.service import UploadValidationError, save_image

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/uploads", tags=["Медиа / Загрузка файлов"])


def _absolute_url(request: Request, url: str) -> str:
    """Относительный путь (/uploads/...) дополняет до абсолютного URL."""
    if url.startswith("http://") or url.startswith("https://"):
        return url
    if settings.public_base_url:
        base = settings.public_base_url.rstrip("/")
    else:
        base = str(request.base_url).rstrip("/")
    return f"{base}{url}"


@router.post("", status_code=status.HTTP_201_CREATED)
async def upload_image(
    request: Request,
    file: UploadFile = File(..., description="Изображение (jpg, png, webp, gif)"),
    folder: str = Query("tours", description="Папка: tours, agencies или misc"),
    current_user: User = Depends(get_current_agency_user),
):
    """Загрузка изображения турагентством/админом.

    Возвращает URL, который нужно подставить в поле photoUrl тура или logoUrl агентства.
    """
    data = await file.read()
    try:
        result = save_image(
            data=data,
            content_type=file.content_type or "",
            filename=file.filename or "",
            folder=folder,
        )
    except UploadValidationError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception as e:
        logger.error("Ошибка загрузки файла: %s", e, exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Не удалось сохранить файл: {e}",
        )

    return {
        "url": _absolute_url(request, result.url),
        "key": result.key,
        "backend": result.backend,
    }


@router.delete("", status_code=status.HTTP_204_NO_CONTENT)
def delete_image(
    key: str = Query(..., description="Ключ файла из ответа загрузки"),
    current_user: User = Depends(get_current_agency_user),
):
    """Удаление ранее загруженного файла по ключу."""
    ok = get_storage_provider().delete(key)
    if not ok:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Файл не найден")
    return None
