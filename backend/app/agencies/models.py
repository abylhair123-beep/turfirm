from datetime import datetime, timezone
import uuid
from sqlalchemy import Boolean, Column, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship

from app.database import Base


class Agency(Base):
    __tablename__ = "agencies"

    id = Column(String(50), primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String(255), unique=True, index=True, nullable=False)
    slug = Column(String(255), unique=True, index=True, nullable=False)
    verified = Column(Boolean, default=False, nullable=False)
    phone = Column(String(50), nullable=True)
    email = Column(String(255), nullable=True)
    address = Column(String(255), nullable=True)
    description = Column(Text, nullable=True)
    rating = Column(Float, default=5.0, nullable=False)
    reviews_count = Column(Integer, default=0, nullable=False)
    logo_url = Column(String(500), nullable=True)
    telegram_chat_id = Column(String(100), nullable=True)  # Чат/канал Telegram для уведомлений о бронях
    bin_iin = Column(String(30), nullable=True)  # БИН / ИИН компании
    legal_address = Column(String(255), nullable=True)  # Юридический адрес
    bank_name = Column(String(100), nullable=True)  # Банк обслуживания
    bank_iban = Column(String(50), nullable=True)  # Расчётный счёт IBAN (KZ...)
    bank_bic = Column(String(30), nullable=True)  # БИК банка
    contact_person = Column(String(150), nullable=True)  # ФИО контактного лица / директора
    user_id = Column(String(36), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)

    # Relationships
    user = relationship("User", back_populates="agency")
    tours = relationship("Tour", back_populates="agency_rel", cascade="all, delete-orphan")
    bookings = relationship("Booking", back_populates="agency_rel")
    payout_requests = relationship("AgencyPayoutRequest", back_populates="agency", cascade="all, delete-orphan")


class AgencyPayoutRequest(Base):
    __tablename__ = "agency_payout_requests"

    id = Column(String(50), primary_key=True, default=lambda: str(uuid.uuid4()))
    agency_id = Column(String(50), ForeignKey("agencies.id", ondelete="CASCADE"), nullable=False, index=True)
    amount = Column(Integer, nullable=False)
    iban = Column(String(50), nullable=False)
    bank_name = Column(String(100), nullable=True)
    status = Column(String(30), default="pending", nullable=False)  # pending, processed, rejected
    comment = Column(Text, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    processed_at = Column(DateTime, nullable=True)

    # Relationship
    agency = relationship("Agency", back_populates="payout_requests")
