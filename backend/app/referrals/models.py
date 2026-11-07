from datetime import datetime, timezone
import uuid
from sqlalchemy import Boolean, Column, DateTime, Float, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.database import Base


class ReferralPartner(Base):
    """Кампания или реферальный код партнёра/блогера."""
    __tablename__ = "referral_partners"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    code = Column(String(50), unique=True, index=True, nullable=False)
    campaign_name = Column(String(100), default="Основная кампания", nullable=False)
    commission_rate = Column(Float, default=3.0, nullable=False)  # 3% от стоимости тура
    fixed_reward = Column(Integer, default=0, nullable=False)     # Фиксированный бонус в тенге
    clicks_count = Column(Integer, default=0, nullable=False)
    bookings_count = Column(Integer, default=0, nullable=False)
    total_earned = Column(Integer, default=0, nullable=False)     # Всего начислено в тенге
    balance = Column(Integer, default=0, nullable=False)          # Доступно к выводу в тенге
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)

    # Relationships
    user = relationship("User", back_populates="referral_campaigns")
    clicks = relationship("ReferralClick", back_populates="partner", cascade="all, delete-orphan")
    payouts = relationship("ReferralPayout", back_populates="partner", cascade="all, delete-orphan")
    bookings = relationship("Booking", back_populates="referral_partner")


class ReferralClick(Base):
    """Трекинг перехода по реферальной ссылке."""
    __tablename__ = "referral_clicks"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    partner_id = Column(String(36), ForeignKey("referral_partners.id", ondelete="CASCADE"), nullable=False, index=True)
    code = Column(String(50), index=True, nullable=False)
    tour_id = Column(String(100), ForeignKey("tours.id", ondelete="SET NULL"), nullable=True)
    ip_address = Column(String(64), nullable=True)
    user_agent = Column(String(255), nullable=True)
    referrer_url = Column(String(500), nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)

    # Relationships
    partner = relationship("ReferralPartner", back_populates="clicks")


class ReferralPayout(Base):
    """Заявка на выплату партнерского вознаграждения."""
    __tablename__ = "referral_payouts"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    partner_id = Column(String(36), ForeignKey("referral_partners.id", ondelete="CASCADE"), nullable=False, index=True)
    amount = Column(Integer, nullable=False)
    payment_details = Column(String(255), nullable=False)
    status = Column(String(30), default="pending", nullable=False)  # "pending", "completed", "rejected"
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)

    # Relationships
    partner = relationship("ReferralPartner", back_populates="payouts")
