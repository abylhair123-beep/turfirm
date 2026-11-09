from datetime import datetime, timedelta, timezone
from typing import List, Optional
import uuid
from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.agencies.excel_export import generate_tourists_manifest_xlsx
from app.agencies.models import Agency, AgencyPayoutRequest
from app.agencies.schemas import (
    AgencyBookingStatusUpdate,
    AgencyCreate,
    AgencyFinanceSummaryResponse,
    AgencyPayoutRequestCreate,
    AgencyPayoutResponse,
    AgencyProfileUpdate,
    AgencyResponse,
    AgencyUpdate,
)
from app.auth.models import User
from app.bookings.models import Booking
from app.bookings.router import _booking_to_response
from app.bookings.schemas import BookingResponse
from app.core.audit import log_audit_event
from app.database import get_db
from app.dependencies import get_current_agency_user, get_current_user
from app.tours.models import Tour
from app.tours.router import _tour_to_response
from app.tours.schemas import TourCreate, TourResponse, TourUpdate

router = APIRouter(prefix="/agencies", tags=["Турагентства"])


def _get_user_agency(current_user: User, db: Session) -> Agency:
    agency = current_user.agency
    if not agency and current_user.role == "admin":
        agency = db.query(Agency).first()
    if not agency:
        raise HTTPException(
            status_code=404,
            detail="Турагентство для данного пользователя не найдено",
        )
    return agency


# --- Личный кабинет турагентства (/agencies/me/...) ---

@router.get("/me/profile", response_model=AgencyResponse)
def get_my_agency_profile(
    current_user: User = Depends(get_current_agency_user),
    db: Session = Depends(get_db),
):
    """Профиль турагентства текущего авторизованного менеджера."""
    return _get_user_agency(current_user, db)


@router.put("/me/profile", response_model=AgencyResponse)
def update_my_agency_profile(
    profile_in: AgencyProfileUpdate,
    current_user: User = Depends(get_current_agency_user),
    db: Session = Depends(get_db),
):
    """Обновление контактных и банковских реквизитов агентства (БИН, IBAN, адрес, контакты)."""
    agency = _get_user_agency(current_user, db)
    update_data = profile_in.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        if hasattr(agency, field):
            setattr(agency, field, value)
    db.commit()
    db.refresh(agency)
    log_audit_event(
        db,
        action="AGENCY_PROFILE_UPDATED",
        resource="agencies",
        user_id=current_user.id,
        user_email=current_user.email,
        details={"agency_id": agency.id, "agency_name": agency.name},
    )
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


@router.post("/me/tours", response_model=TourResponse, status_code=status.HTTP_201_CREATED)
def create_agency_tour(
    tour_in: TourCreate,
    current_user: User = Depends(get_current_agency_user),
    db: Session = Depends(get_db),
):
    """Создание тура текущим турагентством (B2B портал)."""
    agency = _get_user_agency(current_user, db)
    tour_id = tour_in.id or f"tour-{uuid.uuid4().hex[:8]}"
    meta = tour_in.meta or f"{tour_in.nights} · {tour_in.dates} · {tour_in.meal}"

    new_tour = Tour(
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
        departure_city=tour_in.departure_city or "Алматы",
        meta=meta,
        price_from=tour_in.price_from,
        photo_color=tour_in.photo_color or "#0E7C7B",
        photo_url=tour_in.photo_url or "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800",
        description=tour_in.description or "",
        included=tour_in.included or ["Перелет", "Отель", "Трансфер", "Страховка"],
        rating=5.0,
        reviews_count=0,
        is_active=True,
        old_price=tour_in.old_price,
        is_hot=tour_in.is_hot or False,
        seats_left=tour_in.seats_left or 20,
        installment_months=tour_in.installment_months or 12,
        max_guests=tour_in.max_guests or 4,
        hotel_name=tour_in.hotel_name,
        hotel_description=tour_in.hotel_description,
    )
    db.add(new_tour)
    db.commit()
    db.refresh(new_tour)

    log_audit_event(
        db,
        action="AGENCY_TOUR_CREATED",
        resource="tours",
        user_id=current_user.id,
        details={"tour_id": new_tour.id, "title": new_tour.title, "price": new_tour.price_from},
    )
    return _tour_to_response(new_tour)


@router.put("/me/tours/{tour_id}", response_model=TourResponse)
def update_agency_tour(
    tour_id: str,
    tour_update: TourUpdate,
    current_user: User = Depends(get_current_agency_user),
    db: Session = Depends(get_db),
):
    """Редактирование параметров тура текущего агентства."""
    agency = _get_user_agency(current_user, db)
    tour = db.query(Tour).filter(Tour.id == tour_id, Tour.agency_id == agency.id).first()
    if not tour:
        raise HTTPException(
            status_code=404,
            detail="Тур не найден или принадлежит другому агентству",
        )

    data = tour_update.model_dump(exclude_unset=True)
    for k, v in data.items():
        if hasattr(tour, k) and v is not None:
            setattr(tour, k, v)

    db.commit()
    db.refresh(tour)

    log_audit_event(
        db,
        action="AGENCY_TOUR_UPDATED",
        resource="tours",
        user_id=current_user.id,
        details={"tour_id": tour.id, "title": tour.title},
    )
    return _tour_to_response(tour)


@router.delete("/me/tours/{tour_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_agency_tour(
    tour_id: str,
    current_user: User = Depends(get_current_agency_user),
    db: Session = Depends(get_db),
):
    """Удаление тура текущего турагентства."""
    agency = _get_user_agency(current_user, db)
    tour = db.query(Tour).filter(Tour.id == tour_id, Tour.agency_id == agency.id).first()
    if not tour:
        raise HTTPException(
            status_code=404,
            detail="Тур не найден или принадлежит другому агентству",
        )
    db.delete(tour)
    db.commit()

    log_audit_event(
        db,
        action="AGENCY_TOUR_DELETED",
        resource="tours",
        user_id=current_user.id,
        details={"tour_id": tour_id},
    )
    return None


@router.patch("/me/bookings/{booking_id}/status", response_model=BookingResponse)
def update_agency_booking_status(
    booking_id: str,
    payload: AgencyBookingStatusUpdate,
    current_user: User = Depends(get_current_agency_user),
    db: Session = Depends(get_db),
):
    """Смена статуса бронирования менеджером агентства (Подтвержден, Ваучер выдан, Завершен, Отменен)."""
    agency = _get_user_agency(current_user, db)
    booking = db.query(Booking).filter(Booking.id == booking_id, Booking.agency_id == agency.id).first()
    if not booking:
        raise HTTPException(status_code=404, detail="Бронирование не найдено в вашем агентстве")

    allowed_statuses = ["new", "confirmed", "voucher_issued", "completed", "cancelled", "paid"]
    if payload.status not in allowed_statuses:
        raise HTTPException(
            status_code=400,
            detail=f"Недопустимый статус. Разрешены: {', '.join(allowed_statuses)}",
        )

    old_status = booking.status
    booking.status = payload.status
    if payload.note:
        timestamp_str = datetime.now().strftime("%Y-%m-%d %H:%M")
        booking.internal_notes = (
            (booking.internal_notes or "") + f"\n[{timestamp_str}] {payload.note}"
        ).strip()

    db.commit()
    db.refresh(booking)

    log_audit_event(
        db,
        action="BOOKING_STATUS_CHANGED",
        resource="bookings",
        user_id=current_user.id,
        details={"booking_id": booking.id, "old_status": old_status, "new_status": payload.status},
    )
    return _booking_to_response(booking)


@router.get("/me/finances", response_model=AgencyFinanceSummaryResponse)
def get_agency_finances(
    current_user: User = Depends(get_current_agency_user),
    db: Session = Depends(get_db),
):
    """Финансовый баланс агентства, заработанная комиссия (10%) и заявки на выплату."""
    agency = _get_user_agency(current_user, db)

    valid_bookings = db.query(Booking).filter(Booking.agency_id == agency.id, Booking.status != "cancelled").all()
    total_sales = sum(b.total_price for b in valid_bookings)
    commission_rate = 0.10
    total_commission = int(total_sales * commission_rate)

    payouts = db.query(AgencyPayoutRequest).filter(
        AgencyPayoutRequest.agency_id == agency.id
    ).order_by(AgencyPayoutRequest.created_at.desc()).all()

    paid_out = sum(p.amount for p in payouts if p.status == "processed")
    pending = sum(p.amount for p in payouts if p.status == "pending")
    available = max(0, total_commission - paid_out - pending)

    return AgencyFinanceSummaryResponse(
        totalSalesKzt=total_sales,
        commissionRate=commission_rate,
        totalCommissionEarned=total_commission,
        paidOutKzt=paid_out,
        pendingPayoutKzt=pending,
        availableBalanceKzt=available,
        bankIban=agency.bank_iban,
        bankName=agency.bank_name,
        payoutHistory=[
            AgencyPayoutResponse(
                id=p.id,
                amount=p.amount,
                iban=p.iban,
                bankName=p.bank_name,
                status=p.status,
                comment=p.comment,
                createdAt=p.created_at,
                processedAt=p.processed_at,
            )
            for p in payouts
        ],
    )


@router.post("/me/payout-request", response_model=AgencyPayoutResponse, status_code=status.HTTP_201_CREATED)
def create_payout_request(
    payload: AgencyPayoutRequestCreate,
    current_user: User = Depends(get_current_agency_user),
    db: Session = Depends(get_db),
):
    """Подача заявки на вывод агентского комиссионного вознаграждения на IBAN-счет."""
    agency = _get_user_agency(current_user, db)

    iban = (payload.iban or agency.bank_iban or "").strip()
    if not iban:
        raise HTTPException(
            status_code=400,
            detail="Укажите номер IBAN счета (в заявке или в профиле компании)",
        )

    valid_bookings = db.query(Booking).filter(Booking.agency_id == agency.id, Booking.status != "cancelled").all()
    total_sales = sum(b.total_price for b in valid_bookings)
    total_commission = int(total_sales * 0.10)

    payouts = db.query(AgencyPayoutRequest).filter(AgencyPayoutRequest.agency_id == agency.id).all()
    paid_out = sum(p.amount for p in payouts if p.status == "processed")
    pending = sum(p.amount for p in payouts if p.status == "pending")
    available = max(0, total_commission - paid_out - pending)

    if payload.amount > available:
        raise HTTPException(
            status_code=400,
            detail=f"Запрошенная сумма ({payload.amount:,} ₸) превышает доступный остаток ({available:,} ₸)",
        )

    req = AgencyPayoutRequest(
        id=str(uuid.uuid4()),
        agency_id=agency.id,
        amount=payload.amount,
        iban=iban,
        bank_name=payload.bank_name or agency.bank_name or "Банк Казахстана",
        status="pending",
        comment=payload.comment,
        created_at=datetime.now(timezone.utc),
    )
    db.add(req)
    db.commit()
    db.refresh(req)

    log_audit_event(
        db,
        action="AGENCY_PAYOUT_REQUESTED",
        resource="finances",
        user_id=current_user.id,
        details={"amount": req.amount, "iban": req.iban},
    )
    return AgencyPayoutResponse(
        id=req.id,
        amount=req.amount,
        iban=req.iban,
        bankName=req.bank_name,
        status=req.status,
        comment=req.comment,
        createdAt=req.created_at,
    )


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
