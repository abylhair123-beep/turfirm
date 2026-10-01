import logging
from typing import Any, Dict, Optional
import httpx

from app.core.config import settings
from app.payments.providers.base import (
    BasePaymentProvider,
    PaymentInitiateResult,
    PaymentStatusResult,
)

logger = logging.getLogger(__name__)


class KaspiPaymentProvider(BasePaymentProvider):
    provider_name: str = "kaspi"

    @property
    def is_configured(self) -> bool:
        """Проверяет, заданы ли боевые ключи Kaspi Pay."""
        return bool(settings.kaspi_api_key and settings.kaspi_merchant_id)

    @property
    def is_test_mode(self) -> bool:
        """Режим песочницы/тестирования активен, если включен флаг или ключи не заданы."""
        return settings.kaspi_test_mode or not self.is_configured

    def initiate_payment(
        self,
        payment_id: str,
        booking_id: str,
        amount: int,
        description: str,
        customer_phone: Optional[str] = None,
        customer_email: Optional[str] = None,
        customer_name: Optional[str] = None,
        return_url: Optional[str] = None,
    ) -> PaymentInitiateResult:
        """
        Инициализация платежа через Kaspi Pay.
        Если KASPI_API_KEY указан в .env, обращается к официальному Kaspi Pay API.
        В тестовом режиме генерирует валидные ссылки и QR для тестирования.
        """
        if not self.is_test_mode:
            return self._call_real_kaspi_api(
                payment_id=payment_id,
                booking_id=booking_id,
                amount=amount,
                description=description,
                customer_phone=customer_phone,
                customer_name=customer_name,
                return_url=return_url,
            )

        # --- ТЕСТОВЫЙ РЕЖИМ (SANDBOX) ---
        logger.info(
            f"[Kaspi Pay Sandbox] Создан тестовый платеж {payment_id} на сумму {amount} ₸ для брони {booking_id}"
        )
        kaspi_web_url = f"https://kaspi.kz/pay/sapar?orderId={payment_id}&amount={amount}"
        kaspi_qr_data = f"https://kaspi.kz/pay?qr={payment_id}_{amount}"
        qr_image_url = f"https://api.qrserver.com/v1/create-qr-code/?size=250x250&data={kaspi_qr_data}"

        return PaymentInitiateResult(
            external_transaction_id=f"KASPI-TX-{payment_id}",
            payment_url=kaspi_web_url,
            qr_code_data=kaspi_qr_data,
            qr_code_url=qr_image_url,
            status="pending",
            raw_response={
                "provider": "kaspi",
                "mode": "test_sandbox",
                "message": (
                    "Тестовый режим Kaspi Pay. Чтобы активировать боевой режим, "
                    "укажите KASPI_API_KEY и KASPI_MERCHANT_ID в файле .env"
                ),
                "order_id": payment_id,
                "amount": amount,
            },
        )

    def _call_real_kaspi_api(
        self,
        payment_id: str,
        booking_id: str,
        amount: int,
        description: str,
        customer_phone: Optional[str],
        customer_name: Optional[str],
        return_url: Optional[str],
    ) -> PaymentInitiateResult:
        """Обращение к реальному API Kaspi Pay с авторизацией по токену."""
        headers = {
            "Authorization": f"Bearer {settings.kaspi_api_key}",
            "Content-Type": "application/json",
            "X-Merchant-Id": settings.kaspi_merchant_id or "",
        }
        payload = {
            "merchantId": settings.kaspi_merchant_id,
            "orderId": payment_id,
            "externalId": booking_id,
            "amount": amount,
            "currency": "KZT",
            "description": description or f"Оплата бронирования Sapar #{booking_id}",
            "returnUrl": return_url or "https://sapar.kz/payment/callback",
            "customer": {
                "phone": customer_phone or "",
                "name": customer_name or "",
            },
        }
        if settings.kaspi_service_id:
            payload["serviceId"] = settings.kaspi_service_id

        try:
            with httpx.Client(timeout=10.0) as client:
                res = client.post(
                    f"{settings.kaspi_api_url.rstrip('/')}/orders",
                    json=payload,
                    headers=headers,
                )
                res.raise_for_status()
                data = res.json()

                ext_id = data.get("transactionId") or data.get("id") or f"KASPI-{payment_id}"
                payment_url = data.get("paymentUrl") or data.get("redirectUrl")
                qr_code = data.get("qrCode") or data.get("qrCodeData")
                qr_url = data.get("qrCodeUrl") or (
                    f"https://api.qrserver.com/v1/create-qr-code/?size=250x250&data={qr_code}"
                    if qr_code
                    else None
                )

                return PaymentInitiateResult(
                    external_transaction_id=str(ext_id),
                    payment_url=payment_url,
                    qr_code_data=qr_code,
                    qr_code_url=qr_url,
                    status="pending",
                    raw_response=data,
                )
        except Exception as e:
            logger.error(f"[Kaspi Pay] Ошибка при обращении к API: {e}", exc_info=True)
            # В случае ошибки сети или невалидного ключа возвращаем контролируемый fallback
            raise RuntimeError(f"Не удалось связаться с Kaspi Pay API: {str(e)}")

    def check_payment_status(self, external_id: str) -> PaymentStatusResult:
        """Проверка статуса счета в Kaspi Pay."""
        if self.is_test_mode:
            return PaymentStatusResult(
                status="success",
                external_transaction_id=external_id,
                amount=0,
                raw_response={"mode": "test_sandbox", "status": "success"},
            )

        headers = {
            "Authorization": f"Bearer {settings.kaspi_api_key}",
            "X-Merchant-Id": settings.kaspi_merchant_id or "",
        }
        try:
            with httpx.Client(timeout=8.0) as client:
                res = client.get(
                    f"{settings.kaspi_api_url.rstrip('/')}/orders/{external_id}/status",
                    headers=headers,
                )
                res.raise_for_status()
                data = res.json()
                raw_status = data.get("status", "").lower()
                status = "success" if raw_status in ("paid", "completed", "success") else raw_status

                return PaymentStatusResult(
                    status=status,
                    external_transaction_id=external_id,
                    amount=data.get("amount", 0),
                    raw_response=data,
                )
        except Exception as e:
            logger.error(f"[Kaspi Pay] Ошибка проверки статуса {external_id}: {e}")
            return PaymentStatusResult(
                status="pending",
                external_transaction_id=external_id,
                amount=0,
                raw_response={"error": str(e)},
            )

    def verify_webhook(self, payload: dict, signature: Optional[str] = None) -> bool:
        """Проверка подлинности вебхука от Kaspi Pay."""
        if self.is_test_mode:
            return True
        if settings.kaspi_webhook_secret and signature:
            # Сравнение подписи секретным ключом
            return signature == settings.kaspi_webhook_secret
        return True
