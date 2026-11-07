from typing import List, Optional
import uuid
from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app.agencies.models import Agency
from app.auth.models import User
from app.core.cache import cache
from app.core.config import settings
from app.core.limiter import limiter
from app.database import get_db
from app.dependencies import get_current_agency_user, get_current_user
from app.tours.models import Tour
from app.tours.schemas import CategoryItem, TourCreate, TourResponse, TourUpdate

router = APIRouter(prefix="/tours", tags=["Туры"])

# Человеко-читаемые подписи известных тегов удобств.
# Для неизвестных тегов подпись генерируется из самого тега.
AMENITY_LABELS = {
    "all_inclusive": "Всё включено",
    "beach_first_line": "Первая линия",
    "pool": "Бассейн",
    "kids_club": "Детский клуб",
    "spa": "СПА",
    "wifi": "Wi-Fi",
    "city_center": "Центр города",
    "breakfast": "Завтраки",
}


def _amenity_label(tag: str) -> str:
    return AMENITY_LABELS.get(tag, tag.replace("_", " ").capitalize())


def _tour_to_response(tour: Tour) -> TourResponse:
    # Процент скидки считаем из старой цены
    discount_percent = 0
    if tour.old_price and tour.old_price > tour.price_from:
        discount_percent = round((tour.old_price - tour.price_from) / tour.old_price * 100)

    # Платёж в месяц при рассрочке
    months = tour.installment_months or 0
    monthly_payment = round(tour.price_from / months) if months > 0 else None

    return TourResponse(
        id=tour.id,
        agency=tour.agency_name,
        agencyVerified=tour.agency_verified,
        agencyId=tour.agency_id,
        destination=tour.destination,
        title=tour.title,
        category=tour.category,
        nights=tour.nights,
        dates=tour.dates,
        meal=tour.meal,
        departureCity=tour.departure_city,
        meta=tour.meta,
        rating=tour.rating,
        reviewsCount=tour.reviews_count,
        priceFrom=tour.price_from,
        photoColor=tour.photo_color,
        photoUrl=tour.photo_url,
        description=tour.description,
        included=tour.included or [],
        oldPrice=tour.old_price,
        discountPercent=discount_percent,
        isHot=bool(tour.is_hot),
        hotUntil=tour.hot_until,
        seatsLeft=tour.seats_left,
        installmentMonths=months,
        monthlyPayment=monthly_payment,
        maxGuests=tour.max_guests or 4,
        childrenAllowed=bool(tour.children_allowed),
        amenityTags=tour.amenity_tags or [],
        hotelName=tour.hotel_name,
        hotelStars=tour.hotel_stars,
        hotelDescription=tour.hotel_description,
        hotelPhotos=tour.hotel_photos or [],
        hotelAmenities=tour.hotel_amenities or {},
    )


@router.get("/categories", response_model=List[CategoryItem])
def get_categories(request: Request, db: Session = Depends(get_db)):
    cache_key = "sapar:cache:tours:categories"
    cached = cache.get(cache_key)
    if cached is not None:
        return [CategoryItem(**item) for item in cached]

    results = (
        db.query(Tour.category, func.count(Tour.id))
        .filter(Tour.is_active == True)
        .group_by(Tour.category)
        .all()
    )
    categories = [CategoryItem(name=cat, count=cnt) for cat, cnt in results]
    if not categories:
        # Default fallback categories
        for name in ["Пляжный отдых", "Горы", "Визовые туры", "Санатории", "Круизы"]:
            categories.append(CategoryItem(name=name, count=0))

    cache.set(cache_key, [c.model_dump() for c in categories], ttl_seconds=settings.cache_categories_ttl_seconds)
    return categories


@router.get("/filters")
def get_filter_options(db: Session = Depends(get_db)):
    """Доступные значения фильтров, собранные из реального каталога:
    удобства (теги, что задали агентства) и звёздность отелей."""
    tours = db.query(Tour).filter(Tour.is_active == True).all()  # noqa: E712
    tag_counts: dict[str, int] = {}
    stars: set[int] = set()
    for t in tours:
        for tag in (t.amenity_tags or []):
            tag_counts[tag] = tag_counts.get(tag, 0) + 1
        if t.hotel_stars:
            stars.add(t.hotel_stars)

    amenities = [
        {"tag": tag, "label": _amenity_label(tag), "count": count}
        for tag, count in sorted(tag_counts.items(), key=lambda kv: (-kv[1], kv[0]))
    ]
    return {"amenities": amenities, "stars": sorted(stars, reverse=True)}


@router.get("", response_model=List[TourResponse])
@limiter.limit(settings.rate_limit_tours)
def get_tours(
    request: Request,
    category: Optional[str] = Query(None, description="Фильтр по категории (Пляжный отдых, Горы и т.д.)"),
    search: Optional[str] = Query(None, description="Поиск по названию, городу или агентству"),
    departure_city: Optional[str] = Query(None, alias="departureCity", description="Город вылета"),
    min_price: Optional[int] = Query(None, alias="minPrice"),
    max_price: Optional[int] = Query(None, alias="maxPrice"),
    agency_id: Optional[str] = Query(None, alias="agencyId"),
    hot: Optional[bool] = Query(None, description="Только горящие туры"),
    guests: Optional[int] = Query(None, ge=1, description="Всего гостей (взрослые + дети)"),
    children: Optional[int] = Query(None, ge=0, description="Из них детей"),
    amenities: Optional[str] = Query(None, description="Теги удобств через запятую: all_inclusive,beach_first_line"),
    stars: Optional[str] = Query(None, description="Звёздность отеля через запятую: 3,4,5"),
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db),
):
    cache_key = cache.generate_key(
        "tours:list",
        cat=category,
        q=search,
        dep=departure_city,
        min_p=min_price,
        max_p=max_price,
        ag=agency_id,
        hot=hot,
        guests=guests,
        children=children,
        am=amenities,
        st=stars,
        skip=skip,
        lim=limit,
    )
    cached = cache.get(cache_key)
    if cached is not None:
        return [TourResponse(**item) for item in cached]

    query = db.query(Tour).filter(Tour.is_active == True)

    if category and category != "Все":
        query = query.filter(Tour.category == category)

    if departure_city:
        query = query.filter(Tour.departure_city.ilike(f"%{departure_city}%"))

    if min_price is not None:
        query = query.filter(Tour.price_from >= min_price)

    if max_price is not None:
        query = query.filter(Tour.price_from <= max_price)

    if agency_id:
        query = query.filter(Tour.agency_id == agency_id)

    if hot:
        query = query.filter(Tour.is_hot == True)  # noqa: E712

    if guests:
        query = query.filter(Tour.max_guests >= guests)

    if children and children > 0:
        query = query.filter(Tour.children_allowed == True)  # noqa: E712

    if stars:
        star_list = [int(s) for s in stars.split(",") if s.strip().isdigit()]
        if star_list:
            query = query.filter(Tour.hotel_stars.in_(star_list))

    if search:
        search_filter = or_(
            Tour.title.ilike(f"%{search}%"),
            Tour.destination.ilike(f"%{search}%"),
            Tour.agency_name.ilike(f"%{search}%"),
            Tour.description.ilike(f"%{search}%"),
        )
        query = query.filter(search_filter)

    ordered = query.order_by(Tour.rating.desc(), Tour.created_at.desc())

    # Фильтр по тегам удобств (JSON-список) делаем в Python — переносимо между SQLite и Postgres
    required_tags = [t.strip() for t in amenities.split(",") if t.strip()] if amenities else []
    if required_tags:
        all_matching = ordered.all()
        filtered = [t for t in all_matching if set(required_tags).issubset(set(t.amenity_tags or []))]
        tours = filtered[skip: skip + limit]
    else:
        tours = ordered.offset(skip).limit(limit).all()

    results = [_tour_to_response(t) for t in tours]
    cache.set(cache_key, [r.model_dump() for r in results], ttl_seconds=settings.cache_tours_ttl_seconds)
    return results


@router.get("/{tour_id}", response_model=TourResponse)
def get_tour(tour_id: str, db: Session = Depends(get_db)):
    tour = db.query(Tour).filter(Tour.id == tour_id).first()
    if not tour:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Тур не найден")
    return _tour_to_response(tour)


@router.post("", response_model=TourResponse, status_code=status.HTTP_201_CREATED)
def create_tour(
    tour_in: TourCreate,
    current_user: User = Depends(get_current_agency_user),
    db: Session = Depends(get_db),
):
    agency = None
    if current_user.agency:
        agency = current_user.agency
    elif tour_in.agency_id:
        agency = db.query(Agency).filter(Agency.id == tour_in.agency_id).first()

    if not agency and current_user.role == "admin":
        agency = db.query(Agency).first()

    if not agency:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Не найдено турагентство для привязки тура",
        )

    tour_id = tour_in.id or f"tour-{uuid.uuid4().hex[:8]}"
    meta = tour_in.meta or f"{tour_in.nights} · {tour_in.dates} · {tour_in.meal}"

    tour = Tour(
        id=tour_id,
        agency_id=agency.id,
        agency_name=agency.name,
        agency_verified=agency.verified,
        destination=tour_in.destination,
        title=tour_in.title,
        category=tour_in.category,
        nights=tour_in.nights,
        dates=tour_in.dates,
        meal=tour_in.meal,
        departure_city=tour_in.departure_city,
        meta=meta,
        rating=tour_in.rating or 5.0,
        reviews_count=tour_in.reviews_count or 0,
        price_from=tour_in.price_from,
        photo_color=tour_in.photo_color,
        photo_url=tour_in.photo_url,
        description=tour_in.description,
        included=tour_in.included,
        is_active=True,
        old_price=tour_in.old_price,
        is_hot=bool(tour_in.is_hot) if tour_in.is_hot is not None else False,
        hot_until=tour_in.hot_until,
        seats_left=tour_in.seats_left,
        installment_months=tour_in.installment_months if tour_in.installment_months is not None else 12,
        max_guests=tour_in.max_guests if tour_in.max_guests is not None else 4,
        children_allowed=tour_in.children_allowed if tour_in.children_allowed is not None else True,
        amenity_tags=tour_in.amenity_tags or [],
        hotel_name=tour_in.hotel_name,
        hotel_stars=tour_in.hotel_stars,
        hotel_description=tour_in.hotel_description,
        hotel_photos=tour_in.hotel_photos or [],
        hotel_amenities=tour_in.hotel_amenities or {},
    )
    db.add(tour)
    db.commit()
    db.refresh(tour)
    cache.delete_pattern("sapar:cache:tours:*")
    return _tour_to_response(tour)


@router.put("/{tour_id}", response_model=TourResponse)
def update_tour(
    tour_id: str,
    tour_update: TourUpdate,
    current_user: User = Depends(get_current_agency_user),
    db: Session = Depends(get_db),
):
    tour = db.query(Tour).filter(Tour.id == tour_id).first()
    if not tour:
        raise HTTPException(status_code=404, detail="Тур не найден")

    if current_user.role != "admin" and (not current_user.agency or current_user.agency.id != tour.agency_id):
        raise HTTPException(status_code=403, detail="Нет прав на редактирование этого тура")

    for field, val in tour_update.model_dump(exclude_unset=True).items():
        if field == "isActive":
            tour.is_active = val
        elif hasattr(tour, field) and val is not None:
            setattr(tour, field, val)

    db.commit()
    db.refresh(tour)
    cache.delete_pattern("sapar:cache:tours:*")
    return _tour_to_response(tour)


@router.patch("/{tour_id}/toggle-active", response_model=TourResponse)
def toggle_tour_active(
    tour_id: str,
    current_user: User = Depends(get_current_agency_user),
    db: Session = Depends(get_db),
):
    """Быстрая пауза или возобновление продаж тура в 1 клик (is_active = not is_active)."""
    tour = db.query(Tour).filter(Tour.id == tour_id).first()
    if not tour:
        raise HTTPException(status_code=404, detail="Тур не найден")

    if current_user.role != "admin" and (not current_user.agency or current_user.agency.id != tour.agency_id):
        raise HTTPException(status_code=403, detail="Нет прав на управление этим туром")

    tour.is_active = not tour.is_active
    db.commit()
    db.refresh(tour)
    cache.delete_pattern("sapar:cache:tours:*")
    return _tour_to_response(tour)


@router.delete("/{tour_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_tour(
    tour_id: str,
    current_user: User = Depends(get_current_agency_user),
    db: Session = Depends(get_db),
):
    tour = db.query(Tour).filter(Tour.id == tour_id).first()
    if not tour:
        raise HTTPException(status_code=404, detail="Тур не найден")

    if current_user.role != "admin" and (not current_user.agency or current_user.agency.id != tour.agency_id):
        raise HTTPException(status_code=403, detail="Нет прав на удаление этого тура")

    db.delete(tour)
    db.commit()
    cache.delete_pattern("sapar:cache:tours:*")
    return None
