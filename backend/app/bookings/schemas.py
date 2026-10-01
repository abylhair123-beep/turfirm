from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field


class BookingCreate(BaseModel):
    tour_id: str = Field(alias="tourId")
    customer_name: str = Field(alias="customerName")
    customer_phone: str = Field(alias="customerPhone")
    customer_email: str = Field(alias="customerEmail")
    guests_count: int = Field(default=1, alias="guestsCount")
    payment_method: str = Field(default="Kaspi Pay", alias="paymentMethod")

    model_config = {
        "populate_by_name": True,
    }


class BookingStatusUpdate(BaseModel):
    status: str  # "pending", "confirmed", "paid", "cancelled"


class BookingResponse(BaseModel):
    id: str
    tour_id: str = Field(alias="tourId")
    agency_id: str = Field(alias="agencyId")
    customer_name: str = Field(alias="customerName")
    customer_phone: str = Field(alias="customerPhone")
    customer_email: str = Field(alias="customerEmail")
    guests_count: int = Field(alias="guestsCount")
    payment_method: str = Field(alias="paymentMethod")
    tour_price: int = Field(alias="tourPrice")
    service_fee: int = Field(alias="serviceFee")
    total_price: int = Field(alias="totalPrice")
    status: str
    created_at: datetime = Field(alias="createdAt")

    model_config = {
        "populate_by_name": True,
        "from_attributes": True,
    }
