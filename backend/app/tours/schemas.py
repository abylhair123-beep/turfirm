from datetime import datetime
from typing import Dict, List, Optional
from pydantic import BaseModel, Field


class TourBase(BaseModel):
    title: str
    destination: str
    category: str = "Пляжный отдых"
    nights: str
    dates: str
    meal: str
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
    # Маркетинг (необязательно — агентство может задать при создании тура)
    old_price: Optional[int] = Field(default=None, alias="oldPrice")
    is_hot: Optional[bool] = Field(default=None, alias="isHot")
    hot_until: Optional[datetime] = Field(default=None, alias="hotUntil")
    seats_left: Optional[int] = Field(default=None, alias="seatsLeft")
    installment_months: Optional[int] = Field(default=None, alias="installmentMonths")
    max_guests: Optional[int] = Field(default=None, alias="maxGuests")
    children_allowed: Optional[bool] = Field(default=None, alias="childrenAllowed")
    amenity_tags: Optional[List[str]] = Field(default=None, alias="amenityTags")
    hotel_name: Optional[str] = Field(default=None, alias="hotelName")
    hotel_stars: Optional[int] = Field(default=None, alias="hotelStars")
    hotel_description: Optional[str] = Field(default=None, alias="hotelDescription")
    hotel_photos: Optional[List[str]] = Field(default=None, alias="hotelPhotos")
    hotel_amenities: Optional[Dict[str, List[str]]] = Field(default=None, alias="hotelAmenities")


class TourUpdate(BaseModel):
    title: Optional[str] = None
    destination: Optional[str] = None
    category: Optional[str] = None
    nights: Optional[str] = None
    dates: Optional[str] = None
    meal: Optional[str] = None
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
    old_price: Optional[int] = Field(default=None, alias="oldPrice")
    is_hot: Optional[bool] = Field(default=None, alias="isHot")
    hot_until: Optional[datetime] = Field(default=None, alias="hotUntil")
    seats_left: Optional[int] = Field(default=None, alias="seatsLeft")
    installment_months: Optional[int] = Field(default=None, alias="installmentMonths")
    max_guests: Optional[int] = Field(default=None, alias="maxGuests")
    children_allowed: Optional[bool] = Field(default=None, alias="childrenAllowed")
    amenity_tags: Optional[List[str]] = Field(default=None, alias="amenityTags")
    hotel_name: Optional[str] = Field(default=None, alias="hotelName")
    hotel_stars: Optional[int] = Field(default=None, alias="hotelStars")
    hotel_description: Optional[str] = Field(default=None, alias="hotelDescription")
    hotel_photos: Optional[List[str]] = Field(default=None, alias="hotelPhotos")
    hotel_amenities: Optional[Dict[str, List[str]]] = Field(default=None, alias="hotelAmenities")

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
    dates: str
    meal: str
    departure_city: str = Field(alias="departureCity")
    meta: str
    rating: float
    reviews_count: int = Field(alias="reviewsCount")
    price_from: int = Field(alias="priceFrom")
    photo_color: str = Field(alias="photoColor")
    photo_url: Optional[str] = Field(default=None, alias="photoUrl")
    description: str
    included: List[str]
    # --- Маркетинг ---
    old_price: Optional[int] = Field(default=None, alias="oldPrice")
    discount_percent: int = Field(default=0, alias="discountPercent")
    is_hot: bool = Field(default=False, alias="isHot")
    hot_until: Optional[datetime] = Field(default=None, alias="hotUntil")
    seats_left: Optional[int] = Field(default=None, alias="seatsLeft")
    installment_months: int = Field(default=0, alias="installmentMonths")
    monthly_payment: Optional[int] = Field(default=None, alias="monthlyPayment")
    # --- Вместимость и фильтры ---
    max_guests: int = Field(default=4, alias="maxGuests")
    children_allowed: bool = Field(default=True, alias="childrenAllowed")
    amenity_tags: List[str] = Field(default_factory=list, alias="amenityTags")
    # --- Карточка отеля ---
    hotel_name: Optional[str] = Field(default=None, alias="hotelName")
    hotel_stars: Optional[int] = Field(default=None, alias="hotelStars")
    hotel_description: Optional[str] = Field(default=None, alias="hotelDescription")
    hotel_photos: List[str] = Field(default_factory=list, alias="hotelPhotos")
    hotel_amenities: Dict[str, List[str]] = Field(default_factory=dict, alias="hotelAmenities")

    model_config = {
        "populate_by_name": True,
        "from_attributes": True,
    }


class CategoryItem(BaseModel):
    name: str
    count: int
