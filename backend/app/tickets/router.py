from datetime import datetime, timezone
import random
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import desc
from sqlalchemy.orm import Session

from app.auth.models import User
from app.database import get_db
from app.dependencies import get_current_user_optional
from app.tickets.models import TicketBooking, TicketFlight
from app.tickets.schemas import (
    CityOption,
    TicketBookingCreate,
    TicketBookingResponse,
    TicketFlightResponse,
)

router = APIRouter(prefix="/tickets", tags=["Билеты: Авиа & ЖД"])

POPULAR_CITIES = [
    CityOption(city="Алматы", airport_code="ALA", country="Казахстан", is_popular=True),
    CityOption(city="Астана", airport_code="NQZ", country="Казахстан", is_popular=True),
    CityOption(city="Шымкент", airport_code="CIT", country="Казахстан", is_popular=True),
    CityOption(city="Актау", airport_code="SCO", country="Казахстан", is_popular=True),
    CityOption(city="Анталья", airport_code="AYT", country="Турция", is_popular=True),
    CityOption(city="Дубай", airport_code="DXB", country="ОАЭ", is_popular=True),
    CityOption(city="Стамбул", airport_code="IST", country="Турция", is_popular=True),
    CityOption(city="Ташкент", airport_code="TAS", country="Узбекистан", is_popular=True),
    CityOption(city="Актобе", airport_code="AKX", country="Казахстан", is_popular=False),
    CityOption(city="Караганда", airport_code="KGF", country="Казахстан", is_popular=False),
]


@router.get("/cities", response_model=List[CityOption])
def get_ticket_cities():
    """Список популярных городов отправления и прибытия (Казахстан и международные хабы)."""
    return POPULAR_CITIES


@router.get("/search", response_model=List[TicketFlightResponse])
def search_tickets(
    departure_city: Optional[str] = Query(None, description="Город вылета / отправления"),
    arrival_city: Optional[str] = Query(None, description="Город прилёта / назначения"),
    date: Optional[str] = Query(None, description="Дата поездки YYYY-MM-DD"),
    transport_type: str = Query("all", description="all, flight, train"),
    seat_class: Optional[str] = Query(None, description="all, economy, business, coupe, talgo"),
    direct_only: bool = Query(False, description="Только прямые рейсы без пересадок"),
    has_baggage: bool = Query(False, description="Только с включенным багажом"),
    max_price: Optional[int] = Query(None, description="Максимальная цена в ₸"),
    sort_by: str = Query("price_asc", description="price_asc, price_desc, duration_asc, time_asc"),
    limit: int = Query(50, ge=1, le=100),
    db: Session = Depends(get_db),
):
    """Поиск авиарейсов и ЖД поездов с фильтрацией по городам, датам, багажу и ценам."""
    query = db.query(TicketFlight).filter(TicketFlight.is_active.is_(True))

    if transport_type and transport_type != "all":
        query = query.filter(TicketFlight.transport_type == transport_type)

    if departure_city and departure_city != "Все":
        query = query.filter(TicketFlight.departure_city.ilike(f"%{departure_city}%"))

    if arrival_city and arrival_city != "Все":
        query = query.filter(TicketFlight.arrival_city.ilike(f"%{arrival_city}%"))

    if seat_class and seat_class != "all":
        query = query.filter(TicketFlight.seat_class == seat_class)

    if direct_only:
        query = query.filter(TicketFlight.is_direct.is_(True))

    if has_baggage:
        query = query.filter(TicketFlight.baggage_included.is_(True))

    if max_price:
        query = query.filter(TicketFlight.price <= max_price)

    # Сортировка
    if sort_by == "price_asc":
        query = query.order_by(TicketFlight.price.asc())
    elif sort_by == "price_desc":
        query = query.order_by(TicketFlight.price.desc())
    elif sort_by == "duration_asc":
        query = query.order_by(TicketFlight.duration_minutes.asc())
    else:
        query = query.order_by(TicketFlight.departure_time.asc())

    flights = query.limit(limit).all()
    return flights


@router.get("/{flight_id}", response_model=TicketFlightResponse)
def get_ticket_flight(flight_id: str, db: Session = Depends(get_db)):
    """Детальная информация о конкретном авиарейсе или поезде."""
    flight = db.query(TicketFlight).filter(TicketFlight.id == flight_id).first()
    if not flight:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Рейс не найден")
    return flight


@router.post("/book", response_model=TicketBookingResponse, status_code=status.HTTP_201_CREATED)
def book_ticket(
    payload: TicketBookingCreate,
    current_user: Optional[User] = Depends(get_current_user_optional),
    db: Session = Depends(get_db),
):
    """Оформление и мгновенная оплата электронного билета (Kaspi Pay / Карты)."""
    if not payload.terms_accepted:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Для покупки билета требуется согласие с Правилами перевозки и обработкой персональных данных (Закон РК № 94-V)",
        )

    flight = db.query(TicketFlight).filter(TicketFlight.id == payload.flight_id).first()
    if not flight:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Выбранный рейс не найден")

    if flight.available_seats < payload.passengers_count:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Недостаточно мест на рейсе: доступно {flight.available_seats}",
        )

    # Списание мест
    flight.available_seats = max(0, flight.available_seats - payload.passengers_count)

    # Генерация номера билета
    is_train = flight.transport_type == "train"
    if is_train:
        ticket_num = f"КТЖ-{random.randint(100000, 999999)}"
        seats_generated = ", ".join([f"вагон {random.randint(1, 10)}, место {random.randint(1, 36)}" for _ in range(payload.passengers_count)])
    else:
        ticket_num = f"465-{random.randint(1000000000, 9999999999)}"
        letters = ["A", "B", "C", "D", "E", "F"]
        row = random.randint(5, 28)
        seats_generated = ", ".join([f"{row}{letters[i % 6]}" for i in range(payload.passengers_count)])

    total_price = flight.price * payload.passengers_count

    user_id = current_user.id if current_user else None

    booking = TicketBooking(
        flight_id=flight.id,
        user_id=user_id,
        customer_name=payload.customer_name,
        customer_phone=payload.customer_phone,
        customer_email=payload.customer_email,
        document_number=payload.document_number,
        passengers_count=payload.passengers_count,
        total_price=total_price,
        payment_method=payload.payment_method,
        status="paid",
        ticket_number=ticket_num,
        seat_numbers=seats_generated,
        created_at=datetime.now(timezone.utc),
    )
    db.add(booking)
    db.commit()
    db.refresh(booking)

    return booking


@router.get("/bookings/me", response_model=List[TicketBookingResponse])
def get_my_ticket_bookings(
    email: Optional[str] = Query(None, description="Email для поиска билетов без авторизации"),
    current_user: Optional[User] = Depends(get_current_user_optional),
    db: Session = Depends(get_db),
):
    """Список купленных авиабилетов и ЖД билетов текущего пользователя."""
    query = db.query(TicketBooking)

    if current_user:
        query = query.filter((TicketBooking.user_id == current_user.id) | (TicketBooking.customer_email == current_user.email))
    elif email:
        query = query.filter(TicketBooking.customer_email == email)
    else:
        # Если не авторизован и не передан email, возвращаем последние бронирования сессии
        query = query.order_by(desc(TicketBooking.created_at)).limit(20)

    bookings = query.order_by(desc(TicketBooking.created_at)).all()
    return bookings
