from datetime import datetime, timezone
import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, Header, HTTPException, status
from sqlalchemy.orm import Session

from app.auth.models import User
from app.bookings.models import Booking
from app.core.config import settings
from app.database import get_db
from app.dependencies import get_current_user_optional
from app.payments.models import Payment
from app.payments.providers import get_payment_provider
from app.payments.providers.halyk import HalykPaymentProvider
from app.payments.providers.kaspi import KaspiPaymentProvider
from app.payments.schemas import (
    HalykWebhookPayload,
    HalykWebhookResponse,
    KaspiWebhookPayload,
    KaspiWebhookResponse,
    PaymentInitiateRequest,
    PaymentInitiateResponse,
    PaymentRefundRequest,
    PaymentRefundResponse,
    PaymentStatusResponse,
)

router = APIRouter(prefix="/payments", tags=["Платежи (Kaspi Pay / Halyk Bank)"])


def _payment_to_status_response(p: Payment) -> PaymentStatusResponse:
    return PaymentStatusResponse(
        paymentId=p.id,
        bookingId=p.booking_id,
        amount=p.amount,
        currency=p.currency,
        provider=p.provider,
        status=p.status,
        externalTransactionId=p.external_transaction_id,
        createdAt=p.created_at,
        updatedAt=p.updated_at,
    )


@router.get("/config-status", tags=["Платежи (Kaspi Pay / Halyk Bank)"])
def get_payment_config_status():
    """
    Возвращает текущее состояние интеграции с Kaspi Pay и Halyk Bank E-Pay.
    Показывает, работает ли платежная система в тестовом режиме или боевом API.
    """
    kaspi_provider = KaspiPaymentProvider()
    halyk_provider = HalykPaymentProvider()
    return {
        "kaspi": {
            "name": "Kaspi Pay (Kaspi QR / Удаленная оплата)",
            "isConfigured": kaspi_provider.is_configured,
            "isTestMode": kaspi_provider.is_test_mode,
            "merchantId": settings.kaspi_merchant_id if kaspi_provider.is_configured else "Не задан (активен Sandbox)",
            "apiUrl": settings.kaspi_api_url,
            "supportedMethods": ["Kaspi QR", "Kaspi Gold", "Kaspi Ред", "Рассрочка 0-0-12"],
            "activationHint": "Добавьте KASPI_API_KEY и KASPI_MERCHANT_ID в .env и установите KASPI_TEST_MODE=false",
        },
        "halyk": {
            "name": "Halyk Bank E-Pay (epay.halykbank.kz)",
            "isConfigured": halyk_provider.is_configured,
            "isTestMode": halyk_provider.is_test_mode,
            "clientId": settings.halyk_client_id if halyk_provider.is_configured else "Не задан (активен Sandbox)",
            "terminalId": settings.halyk_terminal_id or "Тестовый терминал",
            "apiUrl": settings.halyk_api_url,
            "supportedMethods": ["Visa", "MasterCard", "Apple Pay", "Google Pay", "Halyk QR", "Halyk Рассрочка"],
            "activationHint": "Добавьте HALYK_CLIENT_ID и HALYK_CLIENT_SECRET в .env и установите HALYK_TEST_MODE=false",
        },
        "compliance": {
            "publicOffer": "https://sapar.kz/legal/offer",
            "refundPolicy": "https://sapar.kz/legal/refund",
            "privacyPolicy": "https://sapar.kz/legal/privacy",
            "status": "ready_for_bank_review",
        },
    }


@router.post("/initiate", response_model=PaymentInitiateResponse, status_code=status.HTTP_201_CREATED)
def initiate_payment(
    req: PaymentInitiateRequest,
    current_user: Optional[User] = Depends(get_current_user_optional),
    db: Session = Depends(get_db),
):
    """
    Инициализация платежа (Kaspi Pay QR, банковская карта или Halyk Bank).
    Генерирует счет на оплату, Kaspi QR и ссылку на оплату.
    """
    booking = db.query(Booking).filter(Booking.id == req.booking_id).first()
    if not booking:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Бронирование не найдено",
        )

    provider = get_payment_provider(req.payment_method)
    payment_id = f"PAY-{uuid.uuid4().hex[:8].upper()}"

    phone = req.customer_phone or booking.customer_phone
    email = req.customer_email or booking.customer_email
    name = req.customer_name or booking.customer_name

    try:
        init_res = provider.initiate_payment(
            payment_id=payment_id,
            booking_id=booking.id,
            amount=booking.total_price,
            description=f"Оплата тура по брони #{booking.id}",
            customer_phone=phone,
            customer_email=email,
            customer_name=name,
            return_url=req.return_url,
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Ошибка платежного провайдера: {str(e)}",
        )

    payment = Payment(
        id=payment_id,
        booking_id=booking.id,
        user_id=current_user.id if current_user else booking.user_id,
        amount=booking.total_price,
        currency="KZT",
        provider=provider.provider_name,
        payment_method=req.payment_method,
        status=init_res.status,
        external_transaction_id=init_res.external_transaction_id,
        payment_url=init_res.payment_url,
        qr_code_data=init_res.qr_code_data,
        qr_code_url=init_res.qr_code_url,
        customer_phone=phone,
        customer_email=email,
        customer_name=name,
        meta_data=init_res.raw_response,
    )
    db.add(payment)
    db.commit()
    db.refresh(payment)

    deeplink_url = None
    if payment.provider == "kaspi":
        deeplink_url = f"kaspi://pay?orderId={payment.id}&amount={payment.amount}"
    elif payment.provider == "halyk":
        deeplink_url = f"homebank://pay?invoice={payment.id}&amount={payment.amount}"

    return PaymentInitiateResponse(
        paymentId=payment.id,
        bookingId=payment.booking_id,
        amount=payment.amount,
        currency=payment.currency,
        provider=payment.provider,
        status=payment.status,
        paymentUrl=payment.payment_url,
        deeplinkUrl=deeplink_url,
        qrCodeData=payment.qr_code_data,
        qrCodeUrl=payment.qr_code_url,
        createdAt=payment.created_at,
    )


@router.get("/{payment_id}", response_model=PaymentStatusResponse)
def get_payment_status(payment_id: str, db: Session = Depends(get_db)):
    """Получение текущего статуса платежа."""
    payment = db.query(Payment).filter(Payment.id == payment_id).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Платеж не найден")
    return _payment_to_status_response(payment)


@router.get("/booking/{booking_id}", response_model=List[PaymentStatusResponse])
def get_booking_payments(booking_id: str, db: Session = Depends(get_db)):
    """История платежей по бронированию."""
    payments = db.query(Payment).filter(Payment.booking_id == booking_id).order_by(Payment.created_at.desc()).all()
    return [_payment_to_status_response(p) for p in payments]


@router.post("/{payment_id}/confirm", response_model=PaymentStatusResponse)
def confirm_payment(
    payment_id: str,
    db: Session = Depends(get_db),
):
    """
    Подтверждение платежа (для фронтенда / мобильного приложения после успешного скана Kaspi QR или редиректа).
    Переводит платеж в статус 'success' и бронирование в статус 'paid'.
    """
    payment = db.query(Payment).filter(Payment.id == payment_id).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Платеж не найден")

    payment.status = "success"
    payment.updated_at = datetime.now(timezone.utc)

    # Обновляем статус бронирования
    booking = db.query(Booking).filter(Booking.id == payment.booking_id).first()
    if booking:
        booking.status = "paid"

    db.commit()
    db.refresh(payment)
    return _payment_to_status_response(payment)


@router.post("/kaspi/webhook", response_model=KaspiWebhookResponse)
def kaspi_webhook(
    payload: KaspiWebhookPayload,
    x_signature: Optional[str] = Header(None, alias="X-Signature"),
    db: Session = Depends(get_db),
):
    """
    Вебхук обратного вызова от Kaspi Pay.
    Kaspi Pay отправляет уведомление сюда при оплате покупателем через Kaspi QR / Kaspi Gold.
    """
    kaspi_provider = KaspiPaymentProvider()
    if not kaspi_provider.verify_webhook(payload.model_dump(), x_signature):
        raise HTTPException(status_code=401, detail="Неверная подпись вебхука Kaspi")

    # Ищем платеж по orderId или external_transaction_id
    payment = (
        db.query(Payment)
        .filter((Payment.id == payload.order_id) | (Payment.external_transaction_id == payload.transaction_id))
        .first()
    )

    if not payment:
        raise HTTPException(status_code=404, detail="Платеж не найден")

    if payload.status.lower() in ("paid", "success", "completed"):
        payment.status = "success"
        booking = db.query(Booking).filter(Booking.id == payment.booking_id).first()
        if booking:
            booking.status = "paid"
    elif payload.status.lower() in ("cancelled", "canceled", "failed"):
        payment.status = "failed"

    payment.updated_at = datetime.now(timezone.utc)
    db.commit()

    return KaspiWebhookResponse(
        result="ok",
        orderId=payment.id,
        status=payment.status,
    )


@router.post("/halyk/webhook", response_model=HalykWebhookResponse)
def halyk_webhook(
    payload: HalykWebhookPayload,
    x_signature: Optional[str] = Header(None, alias="X-Signature"),
    db: Session = Depends(get_db),
):
    """
    Вебхук обратного вызова от Halyk Bank E-Pay (epay.halykbank.kz).
    Вызывается банком при успешной оплате картой, Apple Pay / Google Pay или Halyk QR.
    """
    halyk_provider = HalykPaymentProvider()
    if not halyk_provider.verify_webhook(payload.model_dump(), x_signature):
        raise HTTPException(status_code=401, detail="Неверная HMAC-подпись вебхука Halyk E-Pay")

    # Ищем платеж по invoiceId или external_transaction_id
    payment = (
        db.query(Payment)
        .filter((Payment.id == payload.invoice_id) | (Payment.external_transaction_id == payload.reference))
        .first()
    )

    if not payment:
        raise HTTPException(status_code=404, detail="Платеж не найден")

    if payload.status.lower() in ("paid", "success", "completed", "confirmed"):
        payment.status = "success"
        booking = db.query(Booking).filter(Booking.id == payment.booking_id).first()
        if booking:
            booking.status = "paid"
    elif payload.status.lower() in ("cancelled", "canceled", "failed"):
        payment.status = "failed"

    payment.updated_at = datetime.now(timezone.utc)
    db.commit()

    return HalykWebhookResponse(
        result="ok",
        invoiceId=payment.id,
        status=payment.status,
    )


@router.post("/{payment_id}/refund", response_model=PaymentRefundResponse)
def refund_payment(
    payment_id: str,
    req: PaymentRefundRequest,
    db: Session = Depends(get_db),
):
    """
    Возврат денежных средств (Refund) по оплате через Kaspi Pay или Halyk E-Pay.
    Необходимо для соблюдения регламентов банков и политики защиты прав потребителей.
    """
    payment = db.query(Payment).filter(Payment.id == payment_id).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Платеж не найден")

    if payment.status != "success":
        raise HTTPException(
            status_code=400,
            detail=f"Невозможно оформить возврат для платежа со статусом '{payment.status}'",
        )

    refund_amount = req.amount if req.amount is not None else payment.amount
    if refund_amount <= 0 or refund_amount > payment.amount:
        raise HTTPException(
            status_code=400,
            detail=f"Некорректная сумма возврата: {refund_amount} ₸ (макс: {payment.amount} ₸)",
        )

    payment.status = "refunded"
    payment.updated_at = datetime.now(timezone.utc)

    # Обновляем статус бронирования
    booking = db.query(Booking).filter(Booking.id == payment.booking_id).first()
    if booking:
        booking.status = "cancelled"

    db.commit()
    db.refresh(payment)

    return PaymentRefundResponse(
        paymentId=payment.id,
        bookingId=payment.booking_id,
        status=payment.status,
        refundedAmount=refund_amount,
        reason=req.reason,
        processedAt=datetime.now(timezone.utc),
    )
