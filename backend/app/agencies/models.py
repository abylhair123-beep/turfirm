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
    user_id = Column(String(36), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)

    # Relationships
    user = relationship("User", back_populates="agency")
    tours = relationship("Tour", back_populates="agency_rel", cascade="all, delete-orphan")
    bookings = relationship("Booking", back_populates="agency_rel")
