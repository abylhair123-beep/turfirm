from datetime import datetime, timezone
import uuid
from sqlalchemy import Boolean, Column, DateTime, Float, ForeignKey, Integer, JSON, String, Text
from sqlalchemy.orm import relationship

from app.database import Base


class Tour(Base):
    __tablename__ = "tours"

    id = Column(String(100), primary_key=True, default=lambda: str(uuid.uuid4()))
    agency_id = Column(String(50), ForeignKey("agencies.id", ondelete="CASCADE"), nullable=False)
    agency_name = Column(String(255), nullable=False)
    agency_verified = Column(Boolean, default=False, nullable=False)
    destination = Column(String(255), index=True, nullable=False)
    title = Column(String(255), index=True, nullable=False)
    category = Column(String(100), index=True, default="Пляжный отдых", nullable=False)
    nights = Column(String(50), nullable=False)
    dates = Column(String(100), nullable=False)
    meal = Column(String(100), nullable=False)
    departure_city = Column(String(100), index=True, default="Алматы", nullable=False)
    meta = Column(String(255), nullable=False)
    rating = Column(Float, default=5.0, nullable=False)
    reviews_count = Column(Integer, default=0, nullable=False)
    price_from = Column(Integer, nullable=False)
    photo_color = Column(String(20), default="0xFF0E7C77", nullable=False)
    photo_url = Column(String(500), nullable=True)
    description = Column(Text, nullable=False)
    included = Column(JSON, default=list, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)

    # Relationships
    agency_rel = relationship("Agency", back_populates="tours")
    bookings = relationship("Booking", back_populates="tour", cascade="all, delete-orphan")
    reviews = relationship("Review", back_populates="tour", cascade="all, delete-orphan")
