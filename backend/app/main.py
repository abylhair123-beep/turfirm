import logging
import os
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
from fastapi.staticfiles import StaticFiles
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware

# Логи приложения (в т.ч. dev-уведомления) выводим в консоль независимо от uvicorn
_app_logger = logging.getLogger("app")
if not _app_logger.handlers:
    _handler = logging.StreamHandler()
    _handler.setFormatter(logging.Formatter("%(asctime)s | %(levelname)s | %(name)s | %(message)s"))
    _app_logger.addHandler(_handler)
    _app_logger.setLevel(logging.INFO)
    _app_logger.propagate = False

from app.admin.router import router as admin_router
from app.agencies.router import router as agencies_router
from app.auth.router import router as auth_router
from app.bookings.router import router as bookings_router
from app.core.cache import cache
from app.core.config import settings
from app.core.limiter import limiter
from app.crm.router import router as crm_router
from app.database import Base, SessionLocal, engine
from app.favorites.router import router as favorites_router
from app.notifications.router import router as notifications_router
from app.payments.router import router as payments_router
from app.promo.router import router as promo_router
from app.referrals.router import router as referrals_router
from app.reviews.router import router as reviews_router
from app.search.router import router as search_router
from app.seed import seed_data
from app.storage.router import router as storage_router
from app.tours.router import router as tours_router

# Мониторинг ошибок Sentry
if settings.sentry_dsn:
    try:
        import sentry_sdk
        sentry_sdk.init(
            dsn=settings.sentry_dsn,
            environment=settings.sentry_environment or settings.environment,
            traces_sample_rate=settings.sentry_traces_sample_rate,
            send_default_pii=False,
        )
        _app_logger.info("Мониторинг Sentry успешно активирован")
    except Exception as e:
        _app_logger.warning(f"Не удалось инициализировать Sentry SDK: {e}")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Initialize database tables and seed sample data
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        seed_data(db)
    finally:
        db.close()
    # Папка для локальной загрузки медиа
    os.makedirs(settings.upload_dir, exist_ok=True)
    yield


app = FastAPI(
    title=settings.app_name,
    version="1.0.0",
    description="Backend API для маркетплейса турагентств Sapar с поддержкой Kaspi Pay",
    lifespan=lifespan,
)

# Подключение Rate Limiting (slowapi)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)

# CORS configuration
origins = settings.cors_origins if isinstance(settings.cors_origins, list) else ["*"]
if "*" in origins:
    allow_origins = ["*"]
else:
    allow_origins = origins

app.add_middleware(
    CORSMiddleware,
    allow_origins=allow_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth_router, prefix=settings.api_v1_prefix)
app.include_router(agencies_router, prefix=settings.api_v1_prefix)
app.include_router(tours_router, prefix=settings.api_v1_prefix)
app.include_router(bookings_router, prefix=settings.api_v1_prefix)
app.include_router(payments_router, prefix=settings.api_v1_prefix)
app.include_router(notifications_router, prefix=settings.api_v1_prefix)
app.include_router(storage_router, prefix=settings.api_v1_prefix)
app.include_router(favorites_router, prefix=settings.api_v1_prefix)
app.include_router(reviews_router, prefix=settings.api_v1_prefix)
app.include_router(search_router, prefix=settings.api_v1_prefix)
app.include_router(promo_router, prefix=settings.api_v1_prefix)
app.include_router(referrals_router, prefix=settings.api_v1_prefix)
app.include_router(admin_router, prefix=settings.api_v1_prefix)
app.include_router(crm_router, prefix=settings.api_v1_prefix)

# Раздача локально загруженных медиа-файлов по /uploads/...
os.makedirs(settings.upload_dir, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=settings.upload_dir), name="uploads")


@app.get("/", include_in_schema=False)
def root():
    return RedirectResponse(url="/docs")


@app.get("/health", tags=["Система"])
def health_check():
    return {
        "status": "ok",
        "app": settings.app_name,
        "environment": settings.environment,
        "version": "1.0.0",
        "payments": "Kaspi Pay / Card / Halyk",
        "redis": "connected" if cache.ping() else "offline",
        "rate_limiting": "enabled" if settings.rate_limit_enabled else "disabled",
        "sentry": "active" if bool(settings.sentry_dsn) else "disabled",
    }


@app.get(f"{settings.api_v1_prefix}/system/sentry-debug", tags=["Система"])
def trigger_sentry_error():
    """Тестовый эндпоинт для проверки перехвата ошибок в Sentry."""
    raise ZeroDivisionError("Sapar Sentry Debug Test Exception")
