from datetime import datetime, timezone
import uuid
from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship

from app.database import Base


class CallLog(Base):
    __tablename__ = "call_logs"

    id = Column(String(50), primary_key=True, default=lambda: f"CALL-{uuid.uuid4().hex[:8].upper()}")
    direction = Column(String(20), default="outbound", nullable=False)  # "outbound", "inbound"
    target_type = Column(String(20), default="customer", nullable=False)  # "customer", "agency"

    target_name = Column(String(255), nullable=False)
    target_phone = Column(String(50), nullable=False, index=True)

    booking_id = Column(String(50), ForeignKey("bookings.id", ondelete="SET NULL"), nullable=True, index=True)
    user_id = Column(String(36), ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    agency_id = Column(String(50), ForeignKey("agencies.id", ondelete="SET NULL"), nullable=True, index=True)
    manager_id = Column(String(36), ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)

    # Статус звонка: "successful", "no_answer", "busy", "callback_needed", "wrong_number", "declined"
    status = Column(String(30), default="successful", nullable=False, index=True)
    duration_seconds = Column(Integer, default=0, nullable=False)
    notes = Column(Text, nullable=True)
    scheduled_callback_at = Column(DateTime, nullable=True)

    # IP-телефония интеграция (SIP, Mango, Zadarma, Asterisk, Webhook)
    telephony_provider = Column(String(50), default="manual", nullable=False)  # "manual", "mango", "zadarma", "sipuni", "simulator"
    recording_url = Column(String(500), nullable=True)
    external_call_id = Column(String(100), nullable=True, index=True)

    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False, index=True)

    # Relationships
    booking = relationship("Booking", backref="call_logs", foreign_keys=[booking_id])
    manager = relationship("User", foreign_keys=[manager_id])
    user = relationship("User", foreign_keys=[user_id])
    agency = relationship("Agency", foreign_keys=[agency_id])
