from datetime import datetime, timezone
import random
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import desc, func
from sqlalchemy.orm import Session

from app.agencies.models import Agency
from app.auth.models import User
from app.bookings.models import Booking
from app.crm.models import CallLog
from app.crm.schemas import (
    CallLogCreate,
    CallLogResponse,
    CallLogUpdate,
    CallQueueItem,
    CallStatsResponse,
    SimulateVoipCallRequest,
    VoipWebhookPayload,
)
from app.database import get_db
from app.dependencies import get_current_agency_user

router = APIRouter(prefix="/crm/calls", tags=["Мини-CRM: Обзвон клиентов и турфирм"])


def _build_log_response(log: CallLog) -> CallLogResponse:
    manager_name = log.manager.full_name if log.manager else None
    tour_title = None
    if log.booking and log.booking.tour:
        tour_title = log.booking.tour.title

    return CallLogResponse(
        id=log.id,
        direction=log.direction,
        target_type=log.target_type,
        target_name=log.target_name,
        target_phone=log.target_phone,
        booking_id=log.booking_id,
        user_id=log.user_id,
        agency_id=log.agency_id,
        manager_id=log.manager_id,
        manager_name=manager_name,
        tour_title=tour_title,
        status=log.status,
        duration_seconds=log.duration_seconds,
        notes=log.notes,
        scheduled_callback_at=log.scheduled_callback_at,
        telephony_provider=log.telephony_provider,
        recording_url=log.recording_url,
        external_call_id=log.external_call_id,
        created_at=log.created_at,
    )


@router.get("/queue", response_model=List[CallQueueItem])
def get_call_queue(
    target_type: str = Query("all", description="all, customer, agency"),
    search: Optional[str] = Query(None, description="Поиск по имени или телефону"),
    limit: int = Query(50, ge=1, le=100),
    current_user: User = Depends(get_current_agency_user),
    db: Session = Depends(get_db),
):
    """Умная очередь обзвона для менеджера и админа.

    Приоритеты:
    1. Назначенные перезвоны (callback_needed) на текущее время.
    2. Новые бронирования (pending / paid), по которым ещё не было звонка.
    3. Партнёрские турагентства (для B2B сверки).
    """
    queue_items: List[CallQueueItem] = []

    # 1. Клиенты из бронирований
    if target_type in ("all", "customer"):
        booking_query = db.query(Booking).order_by(desc(Booking.created_at)).limit(limit * 2)
        bookings = booking_query.all()

        for b in bookings:
            # Находим последний звонок по этой брони
            last_call = (
                db.query(CallLog)
                .filter(CallLog.booking_id == b.id)
                .order_by(desc(CallLog.created_at))
                .first()
            )

            # Определяем причину и приоритет
            reason = "Новая бронь — подтверждение и виза"
            priority = "high" if b.status in ("paid", "pending") and not last_call else "normal"
            scheduled_callback_at = None

            if last_call:
                if last_call.status == "callback_needed":
                    reason = "Запланирован перезвон клиенту"
                    priority = "callback"
                    scheduled_callback_at = last_call.scheduled_callback_at
                elif last_call.status == "no_answer":
                    reason = "Повторный звонок (ранее не взял трубку)"
                    priority = "high"
                elif last_call.status == "successful":
                    reason = "Контроль перед вылетом / документы"
                    priority = "normal"

            tour_title = b.tour.title if b.tour else "Тур Sapar"

            if search:
                s_lower = search.lower()
                if s_lower not in b.customer_name.lower() and s_lower not in b.customer_phone.lower():
                    continue

            queue_items.append(
                CallQueueItem(
                    id=b.id,
                    target_type="customer",
                    target_name=b.customer_name,
                    target_phone=b.customer_phone,
                    tour_title=tour_title,
                    booking_id=b.id,
                    booking_status=b.status,
                    total_price=b.total_price,
                    priority=priority,
                    last_call_at=last_call.created_at if last_call else None,
                    last_call_status=last_call.status if last_call else None,
                    last_call_notes=last_call.notes if last_call else None,
                    scheduled_callback_at=scheduled_callback_at,
                    reason=reason,
                )
            )

    # 2. Турагентства (партнёрская B2B линия)
    if target_type in ("all", "agency"):
        agencies = db.query(Agency).limit(limit).all()
        for a in agencies:
            if not a.phone:
                continue

            last_call = (
                db.query(CallLog)
                .filter(CallLog.agency_id == a.id)
                .order_by(desc(CallLog.created_at))
                .first()
            )

            if search:
                s_lower = search.lower()
                if s_lower not in a.name.lower() and s_lower not in a.phone.lower():
                    continue

            queue_items.append(
                CallQueueItem(
                    id=a.id,
                    target_type="agency",
                    target_name=a.name,
                    target_phone=a.phone,
                    tour_title=f"Агентство • Рейтинг {a.rating}★",
                    booking_id=None,
                    booking_status="verified" if a.verified else "new",
                    total_price=None,
                    priority="callback" if last_call and last_call.status == "callback_needed" else "normal",
                    last_call_at=last_call.created_at if last_call else None,
                    last_call_status=last_call.status if last_call else None,
                    last_call_notes=last_call.notes if last_call else None,
                    scheduled_callback_at=last_call.scheduled_callback_at if last_call else None,
                    reason="B2B партнёрство и актуализация квот",
                )
            )

    # Сортировка очереди: сначала назначенные перезвоны, затем high, затем normal
    priority_order = {"callback": 0, "high": 1, "normal": 2}
    queue_items.sort(key=lambda item: priority_order.get(item.priority, 3))

    return queue_items[:limit]


@router.get("/logs", response_model=List[CallLogResponse])
def get_call_logs(
    status_filter: Optional[str] = Query(None, alias="status", description="Фильтр по статусу звонка"),
    target_type: Optional[str] = Query(None, description="customer или agency"),
    booking_id: Optional[str] = Query(None, description="Фильтр по ID бронирования"),
    agency_id: Optional[str] = Query(None, description="Фильтр по ID агентства"),
    search: Optional[str] = Query(None, description="Поиск по имени или номеру"),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_user: User = Depends(get_current_agency_user),
    db: Session = Depends(get_db),
):
    """Список всех совершенных звонков с фильтрацией и записями."""
    query = db.query(CallLog)

    if status_filter:
        query = query.filter(CallLog.status == status_filter)
    if target_type:
        query = query.filter(CallLog.target_type == target_type)
    if booking_id:
        query = query.filter(CallLog.booking_id == booking_id)
    if agency_id:
        query = query.filter(CallLog.agency_id == agency_id)
    if search:
        s = f"%{search}%"
        query = query.filter((CallLog.target_name.ilike(s)) | (CallLog.target_phone.ilike(s)))

    logs = query.order_by(desc(CallLog.created_at)).offset(offset).limit(limit).all()
    return [_build_log_response(log) for log in logs]


@router.post("/logs", response_model=CallLogResponse, status_code=status.HTTP_201_CREATED)
def create_call_log(
    payload: CallLogCreate,
    current_user: User = Depends(get_current_agency_user),
    db: Session = Depends(get_db),
):
    """Ручная фиксация звонка менеджером (статус, длительность, комментарий, дата перезвона)."""
    # Если передан booking_id, валидируем его и связываем с клиентом
    user_id = payload.user_id
    agency_id = payload.agency_id
    if payload.booking_id:
        booking = db.query(Booking).filter(Booking.id == payload.booking_id).first()
        if booking:
            if not user_id:
                user_id = booking.user_id
            if not agency_id:
                agency_id = booking.agency_id

    call_log = CallLog(
        direction=payload.direction,
        target_type=payload.target_type,
        target_name=payload.target_name,
        target_phone=payload.target_phone,
        booking_id=payload.booking_id,
        user_id=user_id,
        agency_id=agency_id,
        manager_id=current_user.id,
        status=payload.status,
        duration_seconds=payload.duration_seconds,
        notes=payload.notes,
        scheduled_callback_at=payload.scheduled_callback_at,
        telephony_provider=payload.telephony_provider,
        recording_url=payload.recording_url,
        external_call_id=payload.external_call_id,
    )
    db.add(call_log)
    db.commit()
    db.refresh(call_log)
    return _build_log_response(call_log)


@router.patch("/logs/{call_id}", response_model=CallLogResponse)
def update_call_log(
    call_id: str,
    payload: CallLogUpdate,
    current_user: User = Depends(get_current_agency_user),
    db: Session = Depends(get_db),
):
    """Обновление заметок, статуса или даты перезвона по звонку."""
    log = db.query(CallLog).filter(CallLog.id == call_id).first()
    if not log:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Лог звонка не найден")

    if payload.status is not None:
        log.status = payload.status
    if payload.duration_seconds is not None:
        log.duration_seconds = payload.duration_seconds
    if payload.notes is not None:
        log.notes = payload.notes
    if payload.scheduled_callback_at is not None:
        log.scheduled_callback_at = payload.scheduled_callback_at
    if payload.recording_url is not None:
        log.recording_url = payload.recording_url

    db.commit()
    db.refresh(log)
    return _build_log_response(log)


@router.get("/stats", response_model=CallStatsResponse)
def get_call_stats(
    current_user: User = Depends(get_current_agency_user),
    db: Session = Depends(get_db),
):
    """Сводная аналитика эффективности обзвона менеджеров."""
    all_logs = db.query(CallLog).all()
    total_calls = len(all_logs)

    now = datetime.now(timezone.utc).replace(tzinfo=None)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)

    calls_today = sum(1 for log in all_logs if log.created_at and log.created_at >= today_start)
    successful_calls = sum(1 for log in all_logs if log.status == "successful")
    answer_rate_pct = round((successful_calls / total_calls * 100), 1) if total_calls > 0 else 0.0

    durations = [log.duration_seconds for log in all_logs if log.duration_seconds > 0]
    avg_duration = round(sum(durations) / len(durations)) if durations else 0

    pending_callbacks = sum(1 for log in all_logs if log.status == "callback_needed")

    status_breakdown = {}
    target_type_breakdown = {}
    for log in all_logs:
        status_breakdown[log.status] = status_breakdown.get(log.status, 0) + 1
        target_type_breakdown[log.target_type] = target_type_breakdown.get(log.target_type, 0) + 1

    return CallStatsResponse(
        total_calls=total_calls,
        calls_today=calls_today,
        successful_calls=successful_calls,
        answer_rate_pct=answer_rate_pct,
        avg_duration_seconds=avg_duration,
        pending_callbacks_count=pending_callbacks,
        status_breakdown=status_breakdown,
        target_type_breakdown=target_type_breakdown,
    )


@router.post("/webhook", status_code=status.HTTP_200_OK)
def voip_telephony_webhook(
    payload: VoipWebhookPayload,
    db: Session = Depends(get_db),
):
    """Вебхук от IP-АТС (Mango, Zadarma, Asterisk, Sipuni) для автоматического лога звонков."""
    # Поиск связанной брони по номеру вызываемого или вызывающего
    target_phone = payload.callee_phone if payload.direction == "outbound" else payload.caller_phone
    booking = (
        db.query(Booking)
        .filter(Booking.customer_phone == target_phone)
        .order_by(desc(Booking.created_at))
        .first()
    )

    # Проверка, есть ли уже лог с таким external_call_id
    existing_log = db.query(CallLog).filter(CallLog.external_call_id == payload.external_call_id).first()
    if existing_log:
        existing_log.status = payload.status
        existing_log.duration_seconds = payload.duration_seconds
        if payload.recording_url:
            existing_log.recording_url = payload.recording_url
        db.commit()
        return {"status": "updated", "call_id": existing_log.id}

    new_log = CallLog(
        direction=payload.direction,
        target_type="customer" if booking else "customer",
        target_name=booking.customer_name if booking else f"Абонент {target_phone}",
        target_phone=target_phone,
        booking_id=booking.id if booking else None,
        user_id=booking.user_id if booking else None,
        agency_id=booking.agency_id if booking else None,
        status=payload.status,
        duration_seconds=payload.duration_seconds,
        notes=f"Звонок через IP-телефонию {payload.provider}",
        telephony_provider=payload.provider,
        recording_url=payload.recording_url,
        external_call_id=payload.external_call_id,
    )
    db.add(new_log)
    db.commit()
    db.refresh(new_log)
    return {"status": "created", "call_id": new_log.id}


@router.post("/simulate-voip", response_model=CallLogResponse)
def simulate_voip_call(
    payload: SimulateVoipCallRequest,
    current_user: User = Depends(get_current_agency_user),
    db: Session = Depends(get_db),
):
    """Тестовая симуляция автообзвона / click-to-call через IP-телефонию с генерацией аудиозаписи."""
    durations = {"successful": random.randint(45, 180), "no_answer": 0, "busy": 0}
    duration = durations.get(payload.simulated_outcome, 60)
    recording_url = (
        f"https://storage.sapar.travel/recordings/call-sim-{random.randint(1000, 9999)}.mp3"
        if payload.simulated_outcome == "successful"
        else None
    )

    note_text = payload.notes or (
        "Успешный звонок через IP-телефонию. Клиент подтвердил даты вылета и визовые анкеты."
        if payload.simulated_outcome == "successful"
        else "Абонент не ответил на вызов виртуальной АТС."
    )

    call_log = CallLog(
        direction="outbound",
        target_type=payload.target_type,
        target_name=payload.target_name,
        target_phone=payload.target_phone,
        booking_id=payload.booking_id,
        agency_id=payload.agency_id,
        manager_id=current_user.id,
        status=payload.simulated_outcome,
        duration_seconds=duration,
        notes=note_text,
        telephony_provider="voip_simulator",
        recording_url=recording_url,
        external_call_id=f"VOIP-SIM-{random.randint(100000, 999999)}",
    )
    db.add(call_log)
    db.commit()
    db.refresh(call_log)
    return _build_log_response(call_log)
