from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

from app.core.config import settings

# Проект работает на PostgreSQL. DATABASE_URL задаётся в .env
# (postgresql+psycopg2://...). pool_pre_ping проверяет живость соединения
# перед запросом, чтобы не падать на «протухших» коннектах из пула.
engine = create_engine(
    settings.database_url,
    echo=False,
    pool_pre_ping=True,
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
