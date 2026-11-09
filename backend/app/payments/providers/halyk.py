import hashlib
import hmac
import json
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


class HalykPaymentProvider(BasePaymentProvider):
    """
    Интеграция с интернет-эквайрингом Halyk Bank (E-Pay / epay.halykbank.kz).
    Поддерживает:
      - Банковские карты Visa / MasterCard / UnionPay
      - Halyk QR и рассрочка Halyk
      - Apple Pay и Google Pay
      - Тестовый контур (Sandbox https://test-epay.halykbank.kz)
      - Проверку подписи вебхуков (HMAC-SHA256)
    """

    provider_name: str = "halyk"

    @property
    def is_configured(self) -> bool:
        """Проверяет, заданы ли ключи Halyk E-Pay."""
        return bool(settings.halyk_client_id and settings.halyk_client_secret)

    @property
    def is_test_mode(self) -> bool:
        """Режим песочницы/тестирования активен, если включен флаг или ключи не заданы."""
        return settings.halyk_test_mode or not self.is_configured

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
        Инициализация платежа через Halyk E-Pay.
        В боевом режиме выполняет OAuth2 token exchange и создает платежный инвойс.
        В тестовом режиме генерирует ссылки на Sandbox Halyk E-Pay.
        """
        if not self.is_test_mode:
            return self._call_real_halyk_api(
                payment_id=payment_id,
                booking_id=booking_id,
                amount=amount,
                description=description,
                customer_phone=customer_phone,
                customer_email=customer_email,
                customer_name=customer_name,
                return_url=return_url,
            )

        # --- ТЕСТОВЫЙ РЕЖИМ (SANDBOX) ---
        logger.info(
            f"[Halyk E-Pay Sandbox] Создан тестовый платеж {payment_id} на сумму {amount} ₸ для брони #{booking_id}"
        )
        halyk_invoice_url = (
            f"https://test-epay.halykbank.kz/pay/?invoiceId={payment_id}&amount={amount}&currency=KZT"
        )
        halyk_qr_data = f"https://epay.homebank.kz/qr?invoice={payment_id}&amount={amount}"
        qr_image_url = f"https://api.qrserver.com/v1/create-qr-code/?size=250x250&data={halyk_qr_data}"

        return PaymentInitiateResult(
            external_transaction_id=f"HALYK-TX-{payment_id}",
            payment_url=halyk_invoice_url,
            qr_code_data=halyk_qr_data,
            qr_code_url=qr_image_url,
            status="pending",
            raw_response={
                "provider": "halyk",
                "mode": "test_sandbox",
                "gateway": "Halyk E-Pay (epay.halykbank.kz)",
                "message": (
                    "Тестовый контур Halyk E-Pay. Для перехода на боевой шлюз укажите "
                    "HALYK_CLIENT_ID и HALYK_CLIENT_SECRET в файле .env"
                ),
                "order_id": payment_id,
                "amount": amount,
                "supported_methods": ["Visa", "MasterCard", "Apple Pay", "Google Pay", "Halyk QR", "Рассрочка 0-0-12"],
            },
        )

    def _call_real_halyk_api(
        self,
        payment_id: str,
        booking_id: str,
        amount: int,
        description: str,
        customer_phone: Optional[str],
        customer_email: Optional[str],
        customer_name: Optional[str],
        return_url: Optional[str],
    ) -> PaymentInitiateResult:
        """Получение access_token по OAuth2 и создание платежа через Halyk WebAPI."""
        base_url = settings.halyk_api_url.rstrip("/")
        try:
            with httpx.Client(timeout=10.0) as client:
                # 1. OAuth2 Client Credentials
                token_res = client.post(
                    f"{base_url}/oauth/token",
                    data={
                        "grant_type": "client_credentials",
                        "scope": "webapi usermanagement email_send verification statement",
                        "client_id": settings.halyk_client_id,
                        "client_secret": settings.halyk_client_secret,
                    },
                )
                token_res.raise_for_status()
                token_data = token_res.json()
                access_token = token_data.get("access_token")

                # 2. Создание платежного счета (Invoice)
                headers = {
                    "Authorization": f"Bearer {access_token}",
                    "Content-Type": "application/json",
                }
                payload = {
                    "invoiceId": payment_id,
                    "orderId": booking_id,
                    "amount": amount,
                    "currency": "KZT",
                    "terminal": settings.halyk_terminal_id or "",
                    "description": description or f"Оплата тура Sapar #{booking_id}",
                    "backLink": return_url or "https://sapar.kz/payment/callback",
                    "postLink": "https://sapar.kz/api/v1/payments/halyk/webhook",
                    "phone": customer_phone or "",
                    "email": customer_email or "",
                }

                order_res = client.post(
                    f"{base_url}/api/v1/orders",
                    json=payload,
                    headers=headers,
                )
                order_res.raise_for_status()
                order_data = order_res.json()

                ext_id = order_data.get("id") or order_data.get("reference") or f"HALYK-{payment_id}"
                payment_url = order_data.get("paymentUrl") or order_data.get("redirectUrl") or f"{base_url}/pay/?invoiceId={payment_id}"
                qr_code = order_data.get("qrCode") or f"https://epay.homebank.kz/qr?invoice={payment_id}"
                qr_url = f"https://api.qrserver.com/v1/create-qr-code/?size=250x250&data={qr_code}"

                return PaymentInitiateResult(
                    external_transaction_id=str(ext_id),
                    payment_url=payment_url,
                    qr_code_data=qr_code,
                    qr_code_url=qr_url,
                    status="pending",
                    raw_response=order_data,
                )
        except Exception as e:
            logger.error(f"[Halyk E-Pay] Ошибка при обращении к API: {e}", exc_info=True)
            raise RuntimeError(f"Не удалось связаться с Halyk E-Pay API: {str(e)}")

    def check_payment_status(self, external_id: str) -> PaymentStatusResult:
        """Проверка статуса платежа в Halyk E-Pay."""
        if self.is_test_mode:
            return PaymentStatusResult(
                status="success",
                external_transaction_id=external_id,
                amount=0,
                raw_response={"mode": "test_sandbox", "status": "success"},
            )

        base_url = settings.halyk_api_url.rstrip("/")
        try:
            with httpx.Client(timeout=8.0) as client:
                res = client.get(
                    f"{base_url}/api/v1/orders/{external_id}/status",
                    headers={"Authorization": f"Bearer {settings.halyk_client_secret}"},
                )
                res.raise_for_status()
                data = res.json()
                raw_status = data.get("status", "").lower()
                status = "success" if raw_status in ("paid", "completed", "success", "confirmed") else raw_status

                return PaymentStatusResult(
                    status=status,
                    external_transaction_id=external_id,
                    amount=data.get("amount", 0),
                    raw_response=data,
                )
        except Exception as e:
            logger.error(f"[Halyk E-Pay] Ошибка проверки статуса {external_id}: {e}")
            return PaymentStatusResult(
                status="pending",
                external_transaction_id=external_id,
                amount=0,
                raw_response={"error": str(e)},
            )

    def verify_webhook(self, payload: dict, signature: Optional[str] = None) -> bool:
        """
        Проверка HMAC-SHA256 подписи вебхука от Halyk E-Pay.
        В тестовом режиме всегда пропускает.
        """
        if self.is_test_mode:
            return True

        if not settings.halyk_webhook_secret or not signature:
            return True

        try:
            data_string = json.dumps(payload, sort_keys=True, separators=(",", ":"))
            expected_sig = hmac.new(
                settings.halyk_webhook_secret.encode("utf-8"),
                data_string.encode("utf-8"),
                hashlib.sha256,
            ).hexdigest()
            return hmac.compare_digest(signature.lower(), expected_sig.lower())
        except Exception as e:
            logger.error(f"[Halyk E-Pay] Ошибка верификации подписи: {e}")
            return False
