from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field


class TourBase(BaseModel):
    title: str
    destination: str
    category: str = "Пляжный отдых"
    nights: str
    duration_nights: Optional[int] = Field(default=7, alias="durationNights")
    dates: str
    meal: str
    meal_type: Optional[str] = Field(default="AI", alias="mealType")
    hotel_stars: Optional[int] = Field(default=4, alias="hotelStars")
    beach_line: Optional[int] = Field(default=1, alias="beachLine")
    departure_city: str = Field(default="Алматы", alias="departureCity")
    meta: Optional[str] = None
    price_from: int = Field(alias="priceFrom")
    photo_color: str = Field(default="0xFF0E7C77", alias="photoColor")
    photo_url: Optional[str] = Field(default=None, alias="photoUrl")
    description: str
    included: List[str] = Field(default_factory=list)

    model_config = {
        "populate_by_name": True,
        "from_attributes": True,
    }


class TourCreate(TourBase):
    id: Optional[str] = None
    agency_id: Optional[str] = Field(default=None, alias="agencyId")
    agency: Optional[str] = None
    rating: Optional[float] = 5.0
    reviews_count: Optional[int] = Field(default=0, alias="reviewsCount")


class TourUpdate(BaseModel):
    title: Optional[str] = None
    destination: Optional[str] = None
    category: Optional[str] = None
    nights: Optional[str] = None
    duration_nights: Optional[int] = Field(default=None, alias="durationNights")
    dates: Optional[str] = None
    meal: Optional[str] = None
    meal_type: Optional[str] = Field(default=None, alias="mealType")
    hotel_stars: Optional[int] = Field(default=None, alias="hotelStars")
    beach_line: Optional[int] = Field(default=None, alias="beachLine")
    departure_city: Optional[str] = Field(default=None, alias="departureCity")
    meta: Optional[str] = None
    price_from: Optional[int] = Field(default=None, alias="priceFrom")
    photo_color: Optional[str] = Field(default=None, alias="photoColor")
    photo_url: Optional[str] = Field(default=None, alias="photoUrl")
    description: Optional[str] = None
    included: Optional[List[str]] = None
    rating: Optional[float] = None
    reviews_count: Optional[int] = Field(default=None, alias="reviewsCount")
    is_active: Optional[bool] = Field(default=None, alias="isActive")

    model_config = {
        "populate_by_name": True,
    }


class TourResponse(BaseModel):
    id: str
    agency: str
    agency_verified: bool = Field(alias="agencyVerified")
    agency_id: Optional[str] = Field(default=None, alias="agencyId")
    destination: str
    title: str
    category: str
    nights: str
    duration_nights: Optional[int] = Field(default=7, alias="durationNights")
    dates: str
    meal: str
    meal_type: Optional[str] = Field(default="AI", alias="mealType")
    hotel_stars: Optional[int] = Field(default=4, alias="hotelStars")
    beach_line: Optional[int] = Field(default=1, alias="beachLine")
    departure_city: str = Field(alias="departureCity")
    meta: str
    rating: float
    reviews_count: int = Field(alias="reviewsCount")
    price_from: int = Field(alias="priceFrom")
    photo_color: str = Field(alias="photoColor")
    photo_url: Optional[str] = Field(default=None, alias="photoUrl")
    description: str
    included: List[str]

    model_config = {
        "populate_by_name": True,
        "from_attributes": True,
    }


class CategoryItem(BaseModel):
    name: str
    count: int
