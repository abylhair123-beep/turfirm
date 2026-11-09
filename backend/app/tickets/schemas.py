from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


class TicketFlightResponse(BaseModel):
    id: str
    transport_type: str
    carrier_name: str
    carrier_code: str
    flight_number: str
    departure_city: str
    arrival_city: str
    departure_airport: str
    arrival_airport: str
    departure_time: datetime
    arrival_time: datetime
    duration_minutes: int
    is_direct: bool
    stops_count: int
    baggage_included: bool
    baggage_weight_kg: int
    hand_luggage_kg: int
    seat_class: str
    price: int
    available_seats: int
    aircraft_or_train_model: Optional[str] = None
    provider: str
    is_active: bool
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class TicketBookingCreate(BaseModel):
    flight_id: str = Field(..., description="ID рейса или поезда")
    customer_name: str = Field(..., description="ФИО пассажира")
    customer_phone: str = Field(..., description="Контактный номер телефона")
    customer_email: str = Field(..., description="Email для отправки электронного билета")
    document_number: str = Field(..., description="ИИН (для РК) или номер загранпаспорта")
    passengers_count: int = Field(1, ge=1, le=9, description="Количество пассажиров")
    payment_method: str = Field("Kaspi Pay", description="Kaspi Pay, Картой Visa/Mastercard, Halyk Bank")
    terms_accepted: bool = Field(True, description="Согласие с правилами перевозок и обработкой ПДН")


class TicketBookingResponse(BaseModel):
    id: str
    flight_id: str
    flight: Optional[TicketFlightResponse] = None
    customer_name: str
    customer_phone: str
    customer_email: str
    document_number: str
    passengers_count: int
    total_price: int
    payment_method: str
    status: str
    ticket_number: str
    seat_numbers: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class CityOption(BaseModel):
    city: str
    airport_code: str
    country: str
    is_popular: bool = False
