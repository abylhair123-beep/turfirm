from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.agencies.models import Agency
from app.agencies.schemas import AgencyCreate, AgencyResponse, AgencyUpdate
from app.auth.models import User
from app.bookings.models import Booking
from app.bookings.schemas import BookingResponse
from app.database import get_db
from app.dependencies import get_current_agency_user, get_current_user
from app.tours.models import Tour
from app.tours.router import _tour_to_response
from app.tours.schemas import TourResponse

router = APIRouter(prefix="/agencies", tags=["Турагентства"])


# --- Личный кабинет турагентства (/agencies/me/...) ---

@router.get("/me/profile", response_model=AgencyResponse)
def get_my_agency_profile(
    current_user: User = Depends(get_current_agency_user),
    db: Session = Depends(get_db),
):
    """Профиль турагентства текущего авторизованного менеджера."""
    agency = current_user.agency
    if not agency:
        raise HTTPException(status_code=404, detail="Турагентство для данного пользователя не найдено")
    return agency


@router.get("/me/stats")
def get_my_agency_stats(
    current_user: User = Depends(get_current_agency_user),
    db: Session = Depends(get_db),
):
    """Сводная аналитика для личного кабинета агентства."""
    agency = current_user.agency
    if not agency and current_user.role == "admin":
        agency = db.query(Agency).first()

    if not agency:
        raise HTTPException(status_code=404, detail="Турагентство не привязано к аккаунту")

    tours_count = db.query(Tour).filter(Tour.agency_id == agency.id, Tour.is_active == True).count()
    bookings_query = db.query(Booking).filter(Booking.agency_id == agency.id)

    total_bookings = bookings_query.count()
    paid_bookings = bookings_query.filter(Booking.status == "paid").count()

    total_revenue = (
        db.query(func.sum(Booking.total_price))
        .filter(Booking.agency_id == agency.id, Booking.status == "paid")
        .scalar()
        or 0
    )

    return {
        "agencyId": agency.id,
        "agencyName": agency.name,
        "verified": agency.verified,
        "rating": agency.rating,
        "activeToursCount": tours_count,
        "totalBookings": total_bookings,
        "paidBookings": paid_bookings,
        "totalRevenueKzt": int(total_revenue),
    }


@router.get("/me/tours", response_model=List[TourResponse])
def get_my_agency_tours(
    current_user: User = Depends(get_current_agency_user),
    db: Session = Depends(get_db),
):
    """Все туры, созданные текущим агентством."""
    agency = current_user.agency
    if not agency and current_user.role == "admin":
        agency = db.query(Agency).first()
    if not agency:
        return []
    tours = db.query(Tour).filter(Tour.agency_id == agency.id).order_by(Tour.created_at.desc()).all()
    return [_tour_to_response(t) for t in tours]


# --- Общие эндпоинты турагентств ---

@router.get("", response_model=List[AgencyResponse])
def get_agencies(skip: int = 0, limit: int = 50, db: Session = Depends(get_db)):
    agencies = db.query(Agency).offset(skip).limit(limit).all()
    return agencies


@router.get("/{agency_id}", response_model=AgencyResponse)
def get_agency(agency_id: str, db: Session = Depends(get_db)):
    agency = db.query(Agency).filter(Agency.id == agency_id).first()
    if not agency:
        # Also check by slug
        agency = db.query(Agency).filter(Agency.slug == agency_id).first()
    if not agency:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Турагентство не найдено",
        )
    return agency


@router.post("", response_model=AgencyResponse, status_code=status.HTTP_201_CREATED)
def create_agency(
    agency_in: AgencyCreate,
    current_user: User = Depends(get_current_agency_user),
    db: Session = Depends(get_db),
):
    existing = db.query(Agency).filter(Agency.name == agency_in.name).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Агентство с таким названием уже зарегистрировано",
        )

    slug = agency_in.slug or agency_in.name.lower().replace(" ", "-")
    agency = Agency(
        name=agency_in.name,
        slug=slug,
        phone=agency_in.phone or current_user.phone,
        email=agency_in.email or current_user.email,
        address=agency_in.address,
        description=agency_in.description,
        logo_url=agency_in.logo_url,
        user_id=current_user.id,
        verified=False,
    )
    db.add(agency)
    db.commit()
    db.refresh(agency)
    return agency


@router.patch("/{agency_id}", response_model=AgencyResponse)
def update_agency(
    agency_id: str,
    update_data: AgencyUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    agency = db.query(Agency).filter(Agency.id == agency_id).first()
    if not agency:
        raise HTTPException(status_code=404, detail="Турагентство не найдено")

    if current_user.role != "admin" and agency.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Нет прав на редактирование этого агентства")

    for field, value in update_data.model_dump(exclude_unset=True).items():
        if field == "verified" and current_user.role != "admin":
            continue  # only admin can verify
        setattr(agency, field, value)

    db.commit()
    db.refresh(agency)
    return agency
