from datetime import datetime, timezone
from sqlalchemy import Boolean, Column, DateTime, Integer, String

from app.database import Base


class PromoCode(Base):
    __tablename__ = "promo_codes"

    code = Column(String(50), primary_key=True)  # Хранится в верхнем регистре
    discount_percent = Column(Integer, default=0, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    expires_at = Column(DateTime, nullable=True)
    description = Column(String(255), nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
