import logging
from typing import Optional
from app.payments.providers.base import (
    BasePaymentProvider,
    PaymentInitiateResult,
    PaymentStatusResult,
)

logger = logging.getLogger(__name__)


class CardPaymentProvider(BasePaymentProvider):
    provider_name: str = "card"

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
        logger.info(f"[Card Pay] Инициализирован эквайринг для {payment_id} ({amount} ₸)")
        return PaymentInitiateResult(
            external_transaction_id=f"CARD-TX-{payment_id}",
            payment_url=f"https://checkout.sapar.kz/card?paymentId={payment_id}&amount={amount}",
            status="pending",
            raw_response={"provider": "card", "amount": amount},
        )

    def check_payment_status(self, external_id: str) -> PaymentStatusResult:
        return PaymentStatusResult(
            status="success",
            external_transaction_id=external_id,
            amount=0,
            raw_response={"provider": "card", "status": "success"},
        )

    def verify_webhook(self, payload: dict, signature: Optional[str] = None) -> bool:
        return True


class HalykPaymentProvider(BasePaymentProvider):
    provider_name: str = "halyk"

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
        logger.info(f"[Halyk Bank Epay] Инициализирован платеж для {payment_id} ({amount} ₸)")
        return PaymentInitiateResult(
            external_transaction_id=f"HALYK-TX-{payment_id}",
            payment_url=f"https://epay.homebank.kz/pay?invoiceId={payment_id}&amount={amount}",
            qr_code_url=f"https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=https://epay.homebank.kz/pay?invoiceId={payment_id}",
            status="pending",
            raw_response={"provider": "halyk", "amount": amount},
        )

    def check_payment_status(self, external_id: str) -> PaymentStatusResult:
        return PaymentStatusResult(
            status="success",
            external_transaction_id=external_id,
            amount=0,
            raw_response={"provider": "halyk", "status": "success"},
        )

    def verify_webhook(self, payload: dict, signature: Optional[str] = None) -> bool:
        return True
