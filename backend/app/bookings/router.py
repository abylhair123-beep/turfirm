from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.auth.models import User
from app.bookings.models import Booking
from app.bookings.schemas import BookingCreate, BookingResponse, BookingStatusUpdate
from app.database import get_db
from app.dependencies import get_current_user, get_current_user_optional
from app.tours.models import Tour

router = APIRouter(prefix="/bookings", tags=["Бронирования"])


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
        createdAt=b.created_at,
    )


@router.post("", response_model=BookingResponse, status_code=status.HTTP_201_CREATED)
def create_booking(
    booking_in: BookingCreate,
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
    )
    db.add(booking)
    db.commit()
    db.refresh(booking)

    return _booking_to_response(booking)


@router.get("", response_model=List[BookingResponse])
def get_bookings(
    email: Optional[str] = Query(None, description="Поиск по email клиента"),
    phone: Optional[str] = Query(None, description="Поиск по телефону клиента"),
    agency_id: Optional[str] = Query(None, alias="agencyId"),
    current_user: Optional[User] = Depends(get_current_user_optional),
    db: Session = Depends(get_db),
):
    query = db.query(Booking)

    if current_user:
        if current_user.role == "agency" and current_user.agency:
            query = query.filter(Booking.agency_id == current_user.agency.id)
        elif current_user.role == "client":
            query = query.filter(Booking.user_id == current_user.id)
        # admin can see all or apply filters below
    elif not email and not phone:
        # If not authenticated and no contact filters provided, return empty
        return []

    if email:
        query = query.filter(Booking.customer_email.ilike(f"%{email}%"))
    if phone:
        query = query.filter(Booking.customer_phone.ilike(f"%{phone}%"))
    if agency_id:
        query = query.filter(Booking.agency_id == agency_id)

    bookings = query.order_by(Booking.created_at.desc()).all()
    return [_booking_to_response(b) for b in bookings]


@router.get("/{booking_id}", response_model=BookingResponse)
def get_booking(booking_id: str, db: Session = Depends(get_db)):
    booking = db.query(Booking).filter(Booking.id == booking_id).first()
    if not booking:
        raise HTTPException(status_code=404, detail="Бронирование не найдено")
    return _booking_to_response(booking)


@router.patch("/{booking_id}/status", response_model=BookingResponse)
def update_booking_status(
    booking_id: str,
    status_in: BookingStatusUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    booking = db.query(Booking).filter(Booking.id == booking_id).first()
    if not booking:
        raise HTTPException(status_code=404, detail="Бронирование не найдено")

    if current_user.role != "admin":
        if not current_user.agency or current_user.agency.id != booking.agency_id:
            raise HTTPException(status_code=403, detail="Нет прав на изменение статуса этого бронирования")

    booking.status = status_in.status
    db.commit()
    db.refresh(booking)
    return _booking_to_response(booking)
