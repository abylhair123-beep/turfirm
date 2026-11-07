from datetime import datetime
from typing import Dict, List, Optional
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
    is_promoted: bool = Field(default=False, alias="isPromoted")
    promoted_until: Optional[datetime] = Field(default=None, alias="promotedUntil")
    promotion_tier: Optional[str] = Field(default=None, alias="promotionTier")

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
    old_price: Optional[int] = Field(default=None, alias="oldPrice")
    is_hot: Optional[bool] = Field(default=None, alias="isHot")
    hot_until: Optional[datetime] = Field(default=None, alias="hotUntil")
    seats_left: Optional[int] = Field(default=None, alias="seatsLeft")
    installment_months: Optional[int] = Field(default=None, alias="installmentMonths")
    max_guests: Optional[int] = Field(default=None, alias="maxGuests")
    children_allowed: Optional[bool] = Field(default=None, alias="childrenAllowed")
    amenity_tags: Optional[List[str]] = Field(default=None, alias="amenityTags")
    hotel_name: Optional[str] = Field(default=None, alias="hotelName")
    hotel_description: Optional[str] = Field(default=None, alias="hotelDescription")
    hotel_photos: Optional[List[str]] = Field(default=None, alias="hotelPhotos")
    hotel_amenities: Optional[Dict[str, List[str]]] = Field(default=None, alias="hotelAmenities")
    is_promoted: Optional[bool] = Field(default=None, alias="isPromoted")
    promoted_until: Optional[datetime] = Field(default=None, alias="promotedUntil")
    promotion_tier: Optional[str] = Field(default=None, alias="promotionTier")

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
    hotel_description: Optional[str] = Field(default=None, alias="hotelDescription")
    hotel_photos: List[str] = Field(default_factory=list, alias="hotelPhotos")
    hotel_amenities: Dict[str, List[str]] = Field(default_factory=dict, alias="hotelAmenities")
    # --- Статус и продвижение ---
    is_active: bool = Field(default=True, alias="isActive")
    is_promoted: bool = Field(default=False, alias="isPromoted")
    promoted_until: Optional[datetime] = Field(default=None, alias="promotedUntil")
    promotion_tier: Optional[str] = Field(default=None, alias="promotionTier")

    model_config = {
        "populate_by_name": True,
        "from_attributes": True,
    }


class TourPromoteRequest(BaseModel):
    days: int = Field(default=7, description="Срок продвижения в днях: 3, 7 или 30")
    tier: str = Field(default="top", description="Тариф продвижения: boost, top, vip")
    payment_method: str = Field(default="Kaspi Pay", alias="paymentMethod")

    model_config = {
        "populate_by_name": True,
    }


class TourPromoteResponse(BaseModel):
    tour_id: str = Field(alias="tourId")
    title: str
    is_promoted: bool = Field(alias="isPromoted")
    promoted_until: datetime = Field(alias="promotedUntil")
    promotion_tier: str = Field(alias="promotionTier")
    amount_paid: int = Field(alias="amountPaid")
    message: str

    model_config = {
        "populate_by_name": True,
    }


class CategoryItem(BaseModel):
    name: str
    count: int
