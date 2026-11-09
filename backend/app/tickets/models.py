from datetime import datetime, timezone
import uuid
from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from app.database import Base


class TicketFlight(Base):
    __tablename__ = "ticket_flights"

    id = Column(String(50), primary_key=True, default=lambda: f"FLT-{uuid.uuid4().hex[:8].upper()}")
    transport_type = Column(String(20), default="flight", nullable=False, index=True)  # "flight", "train"

    carrier_name = Column(String(100), nullable=False)  # "Air Astana", "FlyArystan", "SCAT", "КТЖ / Тальго"
    carrier_code = Column(String(10), nullable=False)   # "KC", "IQ", "DV", "KTZ"
    flight_number = Column(String(20), nullable=False)  # "KC-853", "001T"

    departure_city = Column(String(100), nullable=False, index=True)
    arrival_city = Column(String(100), nullable=False, index=True)
    departure_airport = Column(String(100), nullable=False)
    arrival_airport = Column(String(100), nullable=False)

    departure_time = Column(DateTime, nullable=False, index=True)
    arrival_time = Column(DateTime, nullable=False)
    duration_minutes = Column(Integer, nullable=False)

    is_direct = Column(Boolean, default=True, nullable=False)
    stops_count = Column(Integer, default=0, nullable=False)

    baggage_included = Column(Boolean, default=True, nullable=False)
    baggage_weight_kg = Column(Integer, default=20, nullable=False)
    hand_luggage_kg = Column(Integer, default=8, nullable=False)

    seat_class = Column(String(30), default="economy", nullable=False)  # "economy", "business", "comfort", "coupe", "talgo"
    price = Column(Integer, nullable=False)  # цена в тенге ₸
    available_seats = Column(Integer, default=24, nullable=False)

    aircraft_or_train_model = Column(String(100), nullable=True)  # "Airbus A321neo", "Тальго Тулпар"
    provider = Column(String(50), default="sapar_charter", nullable=False)  # "sapar_charter", "amadeus", "aviata", "ktz"
    is_active = Column(Boolean, default=True, nullable=False)

    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)

    # Relationships
    bookings = relationship("TicketBooking", back_populates="flight", cascade="all, delete-orphan")


class TicketBooking(Base):
    __tablename__ = "ticket_bookings"

    id = Column(String(50), primary_key=True, default=lambda: f"TKT-{uuid.uuid4().hex[:8].upper()}")
    flight_id = Column(String(50), ForeignKey("ticket_flights.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(String(36), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)

    customer_name = Column(String(255), nullable=False)
    customer_phone = Column(String(50), nullable=False)
    customer_email = Column(String(255), nullable=False)
    document_number = Column(String(50), nullable=False)  # ИИН или номер паспорта

    passengers_count = Column(Integer, default=1, nullable=False)
    total_price = Column(Integer, nullable=False)
    payment_method = Column(String(50), default="Kaspi Pay", nullable=False)

    status = Column(String(30), default="paid", nullable=False)  # "paid", "pending", "cancelled"
    ticket_number = Column(String(50), nullable=False)  # Электронный номер билета
    seat_numbers = Column(String(100), nullable=True)   # "14A", "14B"

    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)

    # Relationships
    flight = relationship("TicketFlight", back_populates="bookings")
    user = relationship("User")
