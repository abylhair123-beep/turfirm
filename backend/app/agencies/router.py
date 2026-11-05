from datetime import datetime, timedelta, timezone
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.agencies.excel_export import generate_tourists_manifest_xlsx
from app.agencies.models import Agency
from app.agencies.schemas import AgencyCreate, AgencyResponse, AgencyUpdate
from app.auth.models import User
from app.bookings.models import Booking
from app.bookings.router import _booking_to_response
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


@router.get("/me/bookings", response_model=List[BookingResponse])
def get_my_agency_bookings(
    status_filter: Optional[str] = Query(None, alias="status", description="Фильтр: new, confirmed, voucher_issued, completed, cancelled"),
    search: Optional[str] = Query(None, description="Поиск по ФИО, телефону или номеру брони"),
    current_user: User = Depends(get_current_agency_user),
    db: Session = Depends(get_db),
):
    """Список всех заявок и бронирований клиентов текущего агентства (для Канбан-доски)."""
    agency = current_user.agency
    if not agency and current_user.role == "admin":
        agency = db.query(Agency).first()
    if not agency:
        return []

    query = db.query(Booking).filter(Booking.agency_id == agency.id)

    if status_filter:
        if status_filter == "new":
            query = query.filter(Booking.status.in_(["new", "paid", "pending"]))
        else:
            query = query.filter(Booking.status == status_filter)

    if search:
        search_pattern = f"%{search.strip()}%"
        query = query.filter(
            (Booking.customer_name.ilike(search_pattern))
            | (Booking.customer_phone.ilike(search_pattern))
            | (Booking.customer_email.ilike(search_pattern))
            | (Booking.id.ilike(search_pattern))
        )

    bookings = query.order_by(Booking.created_at.desc()).all()
    return [_booking_to_response(b) for b in bookings]


@router.get("/me/bookings/export-xlsx")
def export_agency_bookings_xlsx(
    status_filter: Optional[str] = Query(None, alias="status"),
    current_user: User = Depends(get_current_agency_user),
    db: Session = Depends(get_db),
):
    """Выгрузка списка туристов агентства в Excel (XLSX) для авиакомпаний и отелей."""
    agency = current_user.agency
    if not agency and current_user.role == "admin":
        agency = db.query(Agency).first()
    if not agency:
        raise HTTPException(status_code=404, detail="Агентство не найдено")

    query = db.query(Booking).filter(Booking.agency_id == agency.id)
    if status_filter:
        if status_filter == "new":
            query = query.filter(Booking.status.in_(["new", "paid", "pending"]))
        else:
            query = query.filter(Booking.status == status_filter)

    bookings = query.order_by(Booking.created_at.desc()).all()
    xlsx_bytes = generate_tourists_manifest_xlsx(agency.name, bookings)

    filename = f"sapar_manifest_{agency.slug or 'agency'}_{datetime.now().strftime('%Y%m%d')}.xlsx"
    return Response(
        content=xlsx_bytes,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
            "Content-Type": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        },
    )


@router.get("/me/analytics")
def get_my_agency_analytics(
    period: str = Query("month", description="Период аналитики: week (7 дней), month (30 дней), all"),
    current_user: User = Depends(get_current_agency_user),
    db: Session = Depends(get_db),
):
    """Детальная аналитика продаж агентства: выручка, комиссия, средний чек и график по дням."""
    agency = current_user.agency
    if not agency and current_user.role == "admin":
        agency = db.query(Agency).first()
    if not agency:
        raise HTTPException(status_code=404, detail="Агентство не найдено")

    now = datetime.now(timezone.utc).replace(tzinfo=None)
    if period == "week":
        start_date = now - timedelta(days=7)
        days_count = 7
    elif period == "month":
        start_date = now - timedelta(days=30)
        days_count = 14
    else:
        start_date = None
        days_count = 14

    base_query = db.query(Booking).filter(Booking.agency_id == agency.id)
    all_bookings = base_query.all()

    def _get_naive(dt):
        if dt is None:
            return None
        return dt.replace(tzinfo=None) if getattr(dt, "tzinfo", None) else dt

    # Фильтрация по периоду
    if start_date:
        period_bookings = [b for b in all_bookings if b.created_at and _get_naive(b.created_at) >= start_date]
    else:
        period_bookings = all_bookings

    # Считаем только оплаченные/подтвержденные
    successful_bookings = [b for b in period_bookings if b.status != "cancelled"]
    total_revenue = sum(b.total_price for b in successful_bookings)

    # Комиссионное вознаграждение (10% стандартная ставка турагентства)
    commission_rate = 0.10
    commission_kzt = int(total_revenue * commission_rate)
    average_check = int(total_revenue / len(successful_bookings)) if successful_bookings else 0

    # Воронка статусов (Канбан)
    status_counts = {
        "new": sum(1 for b in all_bookings if b.status in ("new", "paid", "pending")),
        "confirmed": sum(1 for b in all_bookings if b.status == "confirmed"),
        "voucher_issued": sum(1 for b in all_bookings if b.status == "voucher_issued"),
        "completed": sum(1 for b in all_bookings if b.status == "completed"),
        "cancelled": sum(1 for b in all_bookings if b.status == "cancelled"),
        "total": len(all_bookings),
    }

    # Построение графика продаж по дням
    weekday_names = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
    chart_points = []
    for i in range(days_count - 1, -1, -1):
        day_date = (now - timedelta(days=i)).date()
        day_bookings = [
            b for b in all_bookings
            if b.created_at and b.created_at.date() == day_date and b.status != "cancelled"
        ]
        day_rev = sum(b.total_price for b in day_bookings)
        chart_points.append({
            "date": day_date.strftime("%Y-%m-%d"),
            "label": f"{weekday_names[day_date.weekday()]} {day_date.strftime('%d.%m')}",
            "revenue": day_rev,
            "bookingsCount": len(day_bookings),
        })

    return {
        "agencyId": agency.id,
        "agencyName": agency.name,
        "period": period,
        "totalRevenueKzt": total_revenue,
        "commissionKzt": commission_kzt,
        "averageCheckKzt": average_check,
        "totalBookings": len(period_bookings),
        "successfulBookings": len(successful_bookings),
        "statusCounts": status_counts,
        "salesChart": chart_points,
    }



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
