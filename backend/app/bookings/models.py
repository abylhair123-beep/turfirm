from datetime import datetime, timezone
import uuid
from sqlalchemy import Column, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.database import Base


class Booking(Base):
    __tablename__ = "bookings"

    id = Column(String(50), primary_key=True, default=lambda: f"BK-{uuid.uuid4().hex[:8].upper()}")
    tour_id = Column(String(100), ForeignKey("tours.id", ondelete="CASCADE"), nullable=False)
    agency_id = Column(String(50), ForeignKey("agencies.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(String(36), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)

    customer_name = Column(String(255), nullable=False)
    customer_phone = Column(String(50), nullable=False)
    customer_email = Column(String(255), nullable=False)

    guests_count = Column(Integer, default=1, nullable=False)
    payment_method = Column(String(50), default="Kaspi Pay", nullable=False)

    tour_price = Column(Integer, nullable=False)
    service_fee = Column(Integer, default=9800, nullable=False)
    total_price = Column(Integer, nullable=False)

    status = Column(String(30), default="paid", nullable=False)  # "pending", "confirmed", "paid", "cancelled"
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)

    # Relationships
    tour = relationship("Tour", back_populates="bookings")
    agency_rel = relationship("Agency", back_populates="bookings")
    user = relationship("User", back_populates="bookings")
