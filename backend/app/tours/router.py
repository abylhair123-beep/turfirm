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


def _tour_to_response(tour: Tour) -> TourResponse:
    return TourResponse(
        id=tour.id,
        agency=tour.agency_name,
        agencyVerified=tour.agency_verified,
        agencyId=tour.agency_id,
        destination=tour.destination,
        title=tour.title,
        category=tour.category,
        nights=tour.nights,
        durationNights=tour.duration_nights or 7,
        dates=tour.dates,
        meal=tour.meal,
        mealType=tour.meal_type or "AI",
        hotelStars=tour.hotel_stars or 4,
        beachLine=tour.beach_line or 1,
        departureCity=tour.departure_city,
        meta=tour.meta,
        rating=tour.rating,
        reviewsCount=tour.reviews_count,
        priceFrom=tour.price_from,
        photoColor=tour.photo_color,
        photoUrl=tour.photo_url,
        description=tour.description,
        included=tour.included or [],
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


@router.get("", response_model=List[TourResponse])
@limiter.limit(settings.rate_limit_tours)
def get_tours(
    request: Request,
    category: Optional[str] = Query(None, description="Фильтр по категории (Пляжный отдых, Горы и т.д.)"),
    search: Optional[str] = Query(None, description="Поиск по названию, городу или агентству"),
    departure_city: Optional[str] = Query(None, alias="departureCity", description="Город вылета"),
    min_price: Optional[int] = Query(None, alias="minPrice", description="Минимальная цена (₸)"),
    max_price: Optional[int] = Query(None, alias="maxPrice", description="Максимальная цена (₸)"),
    hotel_stars: Optional[int] = Query(None, alias="hotelStars", description="Минимум звёзд отеля (1-5)"),
    meal_type: Optional[str] = Query(None, alias="mealType", description="Тип питания (AI, UAI, BB, HB, FB, RO)"),
    beach_line: Optional[int] = Query(None, alias="beachLine", description="Линия пляжа (1, 2, 3)"),
    duration_nights: Optional[int] = Query(None, alias="durationNights", description="Точная длительность ночей"),
    min_duration: Optional[int] = Query(None, alias="minDuration", description="Минимум ночей"),
    max_duration: Optional[int] = Query(None, alias="maxDuration", description="Максимум ночей"),
    min_rating: Optional[float] = Query(None, alias="minRating", description="Минимальный рейтинг тура (напр. 4.5)"),
    agency_id: Optional[str] = Query(None, alias="agencyId"),
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
        stars=hotel_stars,
        meal=meal_type,
        beach=beach_line,
        dur=duration_nights,
        min_dur=min_duration,
        max_dur=max_duration,
        rating=min_rating,
        ag=agency_id,
        skip=skip,
        lim=limit,
    )
    cached = cache.get(cache_key)
    if cached is not None:
        return [TourResponse(**item) for item in cached]

    query = db.query(Tour).filter(Tour.is_active == True)

    if category and category != "Все":
        query = query.filter(Tour.category == category)

    if departure_city and departure_city != "Любой":
        query = query.filter(Tour.departure_city.ilike(f"%{departure_city}%"))

    if min_price is not None:
        query = query.filter(Tour.price_from >= min_price)

    if max_price is not None:
        query = query.filter(Tour.price_from <= max_price)

    if hotel_stars is not None and hotel_stars > 0:
        query = query.filter(Tour.hotel_stars >= hotel_stars)

    if meal_type and meal_type != "Все":
        query = query.filter(
            or_(
                Tour.meal_type.ilike(f"%{meal_type}%"),
                Tour.meal.ilike(f"%{meal_type}%"),
            )
        )

    if beach_line is not None and beach_line > 0:
        # Ищем отели на этой линии пляжа или ближе (например, запрос 2-я линия покажет 1 и 2)
        query = query.filter(Tour.beach_line <= beach_line)

    if duration_nights is not None:
        query = query.filter(Tour.duration_nights == duration_nights)

    if min_duration is not None:
        query = query.filter(Tour.duration_nights >= min_duration)

    if max_duration is not None:
        query = query.filter(Tour.duration_nights <= max_duration)

    if min_rating is not None:
        query = query.filter(Tour.rating >= min_rating)

    if agency_id:
        query = query.filter(Tour.agency_id == agency_id)

    if search:
        search_filter = or_(
            Tour.title.ilike(f"%{search}%"),
            Tour.destination.ilike(f"%{search}%"),
            Tour.agency_name.ilike(f"%{search}%"),
            Tour.description.ilike(f"%{search}%"),
        )
        query = query.filter(search_filter)

    tours = query.order_by(Tour.rating.desc(), Tour.created_at.desc()).offset(skip).limit(limit).all()
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
        duration_nights=tour_in.duration_nights or 7,
        dates=tour_in.dates,
        meal=tour_in.meal,
        meal_type=tour_in.meal_type or "AI",
        hotel_stars=tour_in.hotel_stars or 4,
        beach_line=tour_in.beach_line or 1,
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
        elif field == "durationNights":
            tour.duration_nights = val
        elif field == "mealType":
            tour.meal_type = val
        elif field == "hotelStars":
            tour.hotel_stars = val
        elif field == "beachLine":
            tour.beach_line = val
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
