"""Сервис уведомлений о бронированиях.

Собирает текст уведомления и рассылает его по каналам (Telegram турагентству,
Email клиенту). Работает с простыми данными (dataclass), а не с ORM-объектами,
чтобы безопасно выполняться в фоне (BackgroundTasks), когда сессия БД уже закрыта.
"""
import logging
from dataclasses import dataclass
from typing import List, Optional

from app.core.config import settings
from app.notifications.providers import (
    NotificationResult,
    email_provider,
    telegram_provider,
)

logger = logging.getLogger(__name__)


@dataclass
class BookingNotificationData:
    """Снимок данных брони для уведомлений (без привязки к сессии БД)."""

    booking_id: str
    status: str
    tour_title: str
    destination: str
    dates: str
    guests_count: int
    total_price: int
    payment_method: str
    customer_name: str
    customer_phone: str
    customer_email: str
    agency_name: str
    agency_telegram_chat_id: Optional[str] = None


def _format_price(amount: int) -> str:
    """42000 -> '42 000 ₸'."""
    return f"{amount:,}".replace(",", " ") + " ₸"


_STATUS_LABELS = {
    "pending": "Ожидает оплаты",
    "confirmed": "Подтверждено",
    "paid": "Оплачено",
    "cancelled": "Отменено",
}


def _status_label(status: str) -> str:
    return _STATUS_LABELS.get(status, status)


def _build_agency_telegram_message(data: BookingNotificationData) -> str:
    """HTML-сообщение для турагентства в Telegram."""
    return (
        f"🧳 <b>Новое бронирование {data.booking_id}</b>\n\n"
        f"<b>Тур:</b> {data.tour_title}\n"
        f"<b>Направление:</b> {data.destination}\n"
        f"<b>Даты:</b> {data.dates}\n"
        f"<b>Гостей:</b> {data.guests_count}\n"
        f"<b>Сумма:</b> {_format_price(data.total_price)}\n"
        f"<b>Оплата:</b> {data.payment_method} ({_status_label(data.status)})\n\n"
        f"<b>Клиент:</b> {data.customer_name}\n"
        f"<b>Телефон:</b> {data.customer_phone}\n"
        f"<b>Email:</b> {data.customer_email}"
    )


def _build_client_email(data: BookingNotificationData) -> tuple[str, str, str]:
    """Тема, текстовая и HTML-версии письма клиенту. Возвращает (subject, text, html)."""
    app_name = settings.public_app_name
    subject = f"{app_name}: подтверждение бронирования {data.booking_id}"

    text = (
        f"Здравствуйте, {data.customer_name}!\n\n"
        f"Ваше бронирование {data.booking_id} принято.\n\n"
        f"Тур: {data.tour_title}\n"
        f"Направление: {data.destination}\n"
        f"Даты: {data.dates}\n"
        f"Гостей: {data.guests_count}\n"
        f"Сумма: {_format_price(data.total_price)}\n"
        f"Статус: {_status_label(data.status)}\n"
        f"Агентство: {data.agency_name}\n\n"
        f"Спасибо, что выбрали {app_name}!"
    )

    html = (
        f"<div style=\"font-family:Arial,sans-serif;max-width:560px;margin:0 auto;color:#1a1a1a\">"
        f"<h2 style=\"color:#0E7C77\">Бронирование {data.booking_id} принято ✅</h2>"
        f"<p>Здравствуйте, <b>{data.customer_name}</b>! Спасибо за бронирование через {app_name}.</p>"
        f"<table style=\"border-collapse:collapse;width:100%\">"
        f"<tr><td style=\"padding:6px 0;color:#666\">Тур</td><td style=\"padding:6px 0\"><b>{data.tour_title}</b></td></tr>"
        f"<tr><td style=\"padding:6px 0;color:#666\">Направление</td><td style=\"padding:6px 0\">{data.destination}</td></tr>"
        f"<tr><td style=\"padding:6px 0;color:#666\">Даты</td><td style=\"padding:6px 0\">{data.dates}</td></tr>"
        f"<tr><td style=\"padding:6px 0;color:#666\">Гостей</td><td style=\"padding:6px 0\">{data.guests_count}</td></tr>"
        f"<tr><td style=\"padding:6px 0;color:#666\">Сумма</td><td style=\"padding:6px 0\"><b>{_format_price(data.total_price)}</b></td></tr>"
        f"<tr><td style=\"padding:6px 0;color:#666\">Статус</td><td style=\"padding:6px 0\">{_status_label(data.status)}</td></tr>"
        f"<tr><td style=\"padding:6px 0;color:#666\">Агентство</td><td style=\"padding:6px 0\">{data.agency_name}</td></tr>"
        f"</table>"
        f"<p style=\"color:#888;font-size:13px;margin-top:24px\">Это письмо сформировано автоматически сервисом {app_name}.</p>"
        f"</div>"
    )
    return subject, text, html


def notify_new_booking(data: BookingNotificationData) -> List[NotificationResult]:
    """Разослать уведомления о новой брони: Telegram агентству + Email клиенту."""
    results: List[NotificationResult] = []

    # 1. Telegram турагентству
    agency_message = _build_agency_telegram_message(data)
    results.append(
        telegram_provider.send(to=data.agency_telegram_chat_id, message=agency_message)
    )

    # 2. Email клиенту
    if data.customer_email:
        subject, text, html = _build_client_email(data)
        results.append(
            email_provider.send(to=data.customer_email, subject=subject, message=text, html=html)
        )

    logger.info(
        "Уведомления по брони %s: %s",
        data.booking_id,
        ", ".join(f"{r.channel}={'ok' if r.success else r.mode}" for r in results),
    )
    return results


def notify_booking_status_change(data: BookingNotificationData) -> List[NotificationResult]:
    """Уведомить клиента об изменении статуса брони (подтверждено/отменено)."""
    results: List[NotificationResult] = []

    if not data.customer_email:
        return results

    app_name = settings.public_app_name
    subject = f"{app_name}: бронирование {data.booking_id} — {_status_label(data.status)}"
    text = (
        f"Здравствуйте, {data.customer_name}!\n\n"
        f"Статус вашего бронирования {data.booking_id} изменён: {_status_label(data.status)}.\n\n"
        f"Тур: {data.tour_title}\n"
        f"Даты: {data.dates}\n"
        f"Агентство: {data.agency_name}\n\n"
        f"С уважением, команда {app_name}."
    )
    results.append(email_provider.send(to=data.customer_email, subject=subject, message=text))

    logger.info(
        "Уведомление о смене статуса брони %s -> %s: email=%s",
        data.booking_id,
        data.status,
        "ok" if results and results[0].success else (results[0].mode if results else "skip"),
    )
    return results
