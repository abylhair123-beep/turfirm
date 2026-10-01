from datetime import datetime, timezone
import uuid
from sqlalchemy import Column, DateTime, ForeignKey, Integer, JSON, String, Text
from sqlalchemy.orm import relationship

from app.database import Base


class Payment(Base):
    __tablename__ = "payments"

    id = Column(String(50), primary_key=True, default=lambda: f"PAY-{uuid.uuid4().hex[:8].upper()}")
    booking_id = Column(String(50), ForeignKey("bookings.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id = Column(String(36), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)

    amount = Column(Integer, nullable=False)
    currency = Column(String(10), default="KZT", nullable=False)
    provider = Column(String(50), default="kaspi", nullable=False)  # "kaspi", "card", "halyk"
    payment_method = Column(String(50), default="Kaspi Pay", nullable=False)

    status = Column(String(30), default="pending", nullable=False)  # "pending", "processing", "success", "failed", "cancelled", "refunded"
    external_transaction_id = Column(String(100), nullable=True, index=True)

    payment_url = Column(String(500), nullable=True)
    qr_code_data = Column(Text, nullable=True)
    qr_code_url = Column(String(500), nullable=True)

    customer_phone = Column(String(50), nullable=True)
    customer_email = Column(String(255), nullable=True)
    customer_name = Column(String(255), nullable=True)

    meta_data = Column(JSON, default=dict, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False)

    # Relationships
    booking = relationship("Booking", back_populates="payments")
    user = relationship("User", back_populates="payments")
