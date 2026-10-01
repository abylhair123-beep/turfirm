from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse

from app.agencies.router import router as agencies_router
from app.auth.router import router as auth_router
from app.bookings.router import router as bookings_router
from app.core.config import settings
from app.database import Base, SessionLocal, engine
from app.favorites.router import router as favorites_router
from app.payments.router import router as payments_router
from app.reviews.router import router as reviews_router
from app.seed import seed_data
from app.tours.router import router as tours_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Initialize database tables and seed sample data
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        seed_data(db)
    finally:
        db.close()
    yield


app = FastAPI(
    title=settings.app_name,
    version="1.0.0",
    description="Backend API для маркетплейса турагентств Sapar с поддержкой Kaspi Pay",
    lifespan=lifespan,
)

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
app.include_router(favorites_router, prefix=settings.api_v1_prefix)
app.include_router(reviews_router, prefix=settings.api_v1_prefix)


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
    }
