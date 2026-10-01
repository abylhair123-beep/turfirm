from dataclasses import dataclass, field
from typing import Any, Dict, Optional


@dataclass
class PaymentInitiateResult:
    external_transaction_id: str
    payment_url: Optional[str] = None
    qr_code_data: Optional[str] = None
    qr_code_url: Optional[str] = None
    status: str = "pending"
    raw_response: Dict[str, Any] = field(default_factory=dict)


@dataclass
class PaymentStatusResult:
    status: str
    external_transaction_id: str
    amount: int
    raw_response: Dict[str, Any] = field(default_factory=dict)


class BasePaymentProvider:
    provider_name: str = "base"

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
        raise NotImplementedError

    def check_payment_status(self, external_id: str) -> PaymentStatusResult:
        raise NotImplementedError

    def verify_webhook(self, payload: dict, signature: Optional[str] = None) -> bool:
        raise NotImplementedError
