from datetime import datetime, timezone
from typing import List, Optional
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, Response, status
from sqlalchemy.orm import Session

from app.agencies.models import Agency
from app.auth.models import User
from app.bookings.models import Booking
from app.bookings.schemas import BookingCreate, BookingResponse, BookingStatusUpdate
from app.bookings.voucher import build_travel_voucher_pdf
from app.core.cache import cache
from app.database import get_db
from app.dependencies import get_current_user, get_current_user_optional
from app.notifications.service import (
    BookingNotificationData,
    notify_booking_status_change,
    notify_new_booking,
)
from app.tours.models import Tour

router = APIRouter(prefix="/bookings", tags=["Бронирования"])


def _build_notification_data(db: Session, booking: Booking, tour: Tour) -> BookingNotificationData:
    """Собрать снимок данных брони для уведомлений, пока сессия БД открыта."""
    agency = db.query(Agency).filter(Agency.id == booking.agency_id).first()
    return BookingNotificationData(
        booking_id=booking.id,
        status=booking.status,
        tour_title=tour.title if tour else "—",
        destination=tour.destination if tour else "—",
        dates=tour.dates if tour else "—",
        guests_count=booking.guests_count,
        total_price=booking.total_price,
        payment_method=booking.payment_method,
        customer_name=booking.customer_name,
        customer_phone=booking.customer_phone,
        customer_email=booking.customer_email,
        agency_name=agency.name if agency else "—",
        agency_telegram_chat_id=agency.telegram_chat_id if agency else None,
    )


def _booking_to_response(b: Booking) -> BookingResponse:
    return BookingResponse(
        id=b.id,
        tourId=b.tour_id,
        agencyId=b.agency_id,
        customerName=b.customer_name,
        customerPhone=b.customer_phone,
        customerEmail=b.customer_email,
        guestsCount=b.guests_count,
        paymentMethod=b.payment_method,
        tourPrice=b.tour_price,
        serviceFee=b.service_fee,
        totalPrice=b.total_price,
        status=b.status,
        internalNotes=getattr(b, "internal_notes", None),
        referralCode=b.referral_code,
        referralReward=b.referral_reward or 0,
        createdAt=b.created_at,
    )


@router.post("", response_model=BookingResponse, status_code=status.HTTP_201_CREATED)
def create_booking(
    booking_in: BookingCreate,
    background_tasks: BackgroundTasks,
    current_user: Optional[User] = Depends(get_current_user_optional),
    db: Session = Depends(get_db),
):
    tour = db.query(Tour).filter(Tour.id == booking_in.tour_id).first()
    if not tour:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Выбранный тур не найден",
        )

    tour_price = tour.price_from
    service_fee = 9800
    guests = max(1, booking_in.guests_count)
    total_price = (tour_price * guests) + service_fee

    # Если по туру ведём учёт мест — проверяем, что их хватает
    if tour.seats_left is not None and tour.seats_left < guests:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Недостаточно свободных мест: осталось {tour.seats_left}",
        )

    # Обработка реферального кода блогера/партнера
    referral_code = booking_in.referral_code.strip().upper() if booking_in.referral_code and booking_in.referral_code.strip() else None
    referral_partner = None
    referral_reward = 0
    if referral_code:
        from app.referrals.models import ReferralPartner
        referral_partner = (
            db.query(ReferralPartner)
            .filter(ReferralPartner.code == referral_code, ReferralPartner.is_active.is_(True))
            .first()
        )
        if referral_partner:
            rate = referral_partner.commission_rate if referral_partner.commission_rate is not None else 3.0
            referral_reward = int((tour_price * guests) * (rate / 100.0)) + (referral_partner.fixed_reward or 0)
            referral_partner.bookings_count += 1
            referral_partner.total_earned += referral_reward
            referral_partner.balance += referral_reward
            db.add(referral_partner)

    booking = Booking(
        tour_id=tour.id,
        agency_id=tour.agency_id,
        user_id=current_user.id if current_user else None,
        customer_name=booking_in.customer_name,
        customer_phone=booking_in.customer_phone,
        customer_email=booking_in.customer_email.lower(),
        guests_count=guests,
        payment_method=booking_in.payment_method,
        tour_price=tour_price,
        service_fee=service_fee,
        total_price=total_price,
        status="paid",  # Mark as paid since user selects payment method and pays
        referral_code=referral_partner.code if referral_partner else referral_code,
        referral_reward=referral_reward,
        referral_partner_id=referral_partner.id if referral_partner else None,
    )
    db.add(booking)

    # Списываем забронированные места (если ведём учёт по туру)
    if tour.seats_left is not None:
        tour.seats_left = max(0, tour.seats_left - guests)

    db.commit()
    db.refresh(booking)

    # Каталог кэшируется — сбрасываем кэш, чтобы новый остаток мест подтянулся
    cache.delete_pattern("sapar:cache:tours:*")

    # Уведомления о новой брони (Telegram агентству + Email клиенту) — в фоне,
    # чтобы ответ не тормозил и сбой отправки не ломал бронирование.
    notification_data = _build_notification_data(db, booking, tour)
    background_tasks.add_task(notify_new_booking, notification_data)

    return _booking_to_response(booking)


@router.get("", response_model=List[BookingResponse])
def get_bookings(
    agency_id: Optional[str] = Query(None, alias="agencyId"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Список бронирований с жестким разграничением прав:
    - client: только свои бронирования
    - agency: только бронирования туров своего агентства
    - admin: все бронирования платформы (с опциональным фильтром agencyId)
    """
    query = db.query(Booking)

    if current_user.role == "client":
        query = query.filter(Booking.user_id == current_user.id)
    elif current_user.role == "agency":
        if not current_user.agency:
            return []
        query = query.filter(Booking.agency_id == current_user.agency.id)
    elif current_user.role == "admin":
        if agency_id:
            query = query.filter(Booking.agency_id == agency_id)
    else:
        return []

    bookings = query.order_by(Booking.created_at.desc()).all()
    return [_booking_to_response(b) for b in bookings]


@router.get("/{booking_id}", response_model=BookingResponse)
def get_booking(
    booking_id: str,
    current_user: Optional[User] = Depends(get_current_user_optional),
    db: Session = Depends(get_db),
):
    """Получение детальной информации о бронировании с проверкой прав доступа:
    - Зарегистрированные бронирования защищены и доступны только владельцу, агентству тура или админу.
    """
    booking = db.query(Booking).filter(Booking.id == booking_id).first()
    if not booking:
        raise HTTPException(status_code=404, detail="Бронирование не найдено")

    if booking.user_id:
        if not current_user:
            raise HTTPException(status_code=401, detail="Требуется авторизация для просмотра этого бронирования")
        if current_user.role == "client" and booking.user_id != current_user.id:
            raise HTTPException(status_code=403, detail="Доступ запрещен: чужое бронирование")
        if current_user.role == "agency" and (not current_user.agency or booking.agency_id != current_user.agency.id):
            raise HTTPException(status_code=403, detail="Доступ запрещен: бронирование другого турагентства")

    return _booking_to_response(booking)


@router.get("/{booking_id}/voucher.pdf", response_class=Response)
def get_booking_voucher_pdf(
    booking_id: str,
    current_user: Optional[User] = Depends(get_current_user_optional),
    db: Session = Depends(get_db),
):
    """Генерация официального туристического PDF-ваучера с QR-кодом, отелем, трансфером и страховкой."""
    booking = db.query(Booking).filter(Booking.id == booking_id).first()
    if not booking:
        raise HTTPException(status_code=404, detail="Бронирование не найдено")

    if current_user:
        if current_user.role == "client" and booking.user_id and booking.user_id != current_user.id:
            raise HTTPException(status_code=403, detail="Доступ запрещен: чужой ваучер")
        if current_user.role == "agency" and (not current_user.agency or booking.agency_id != current_user.agency.id):
            raise HTTPException(status_code=403, detail="Доступ запрещен: ваучер другого агентства")

    tour = db.query(Tour).filter(Tour.id == booking.tour_id).first()
    agency = db.query(Agency).filter(Agency.id == booking.agency_id).first()

    pdf_bytes = build_travel_voucher_pdf(booking, tour, agency)

    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'inline; filename="sapar_voucher_{booking.id}.pdf"',
            "Content-Type": "application/pdf",
        },
    )


@router.get("/{booking_id}/verify")
def verify_booking_voucher(booking_id: str, db: Session = Depends(get_db)):
    """Публичная верификация подлинности ваучера при сканировании QR-кода."""
    booking = db.query(Booking).filter(Booking.id == booking_id).first()
    if not booking:
        return {
            "valid": False,
            "message": "Ваучер не найден или недействителен в системе SAPAR",
        }

    tour = db.query(Tour).filter(Tour.id == booking.tour_id).first()
    agency = db.query(Agency).filter(Agency.id == booking.agency_id).first()

    return {
        "valid": True,
        "bookingId": booking.id,
        "status": booking.status,
        "customerName": booking.customer_name,
        "guestsCount": booking.guests_count,
        "tourTitle": tour.title if tour else "—",
        "dates": tour.dates if tour else "—",
        "agencyName": agency.name if agency else "—",
        "verifiedAt": datetime.now(timezone.utc).isoformat(),
        "message": "Туристический ваучер подлинный, подтвержден и зарегистрирован в экосистеме SAPAR",
    }


@router.patch("/{booking_id}/status", response_model=BookingResponse)
def update_booking_status(
    booking_id: str,
    status_in: BookingStatusUpdate,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    booking = db.query(Booking).filter(Booking.id == booking_id).first()
    if not booking:
        raise HTTPException(status_code=404, detail="Бронирование не найдено")

    if current_user.role != "admin":
        if not current_user.agency or current_user.agency.id != booking.agency_id:
            raise HTTPException(status_code=403, detail="Нет прав на изменение статуса этого бронирования")

    previous_status = booking.status
    booking.status = status_in.status
    db.commit()
    db.refresh(booking)

    # Уведомляем клиента о смене статуса (только если статус реально изменился)
    if previous_status != booking.status:
        tour = db.query(Tour).filter(Tour.id == booking.tour_id).first()
        notification_data = _build_notification_data(db, booking, tour)
        background_tasks.add_task(notify_booking_status_change, notification_data)

    return _booking_to_response(booking)
