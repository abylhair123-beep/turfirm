from typing import Dict
from app.payments.providers.base import BasePaymentProvider
from app.payments.providers.card import CardPaymentProvider, HalykPaymentProvider
from app.payments.providers.kaspi import KaspiPaymentProvider

_PROVIDERS: Dict[str, BasePaymentProvider] = {
    "kaspi": KaspiPaymentProvider(),
    "kaspi pay": KaspiPaymentProvider(),
    "card": CardPaymentProvider(),
    "карта": CardPaymentProvider(),
    "halyk": HalykPaymentProvider(),
    "halyk bank": HalykPaymentProvider(),
}


def get_payment_provider(method_name: str) -> BasePaymentProvider:
    key = (method_name or "kaspi").lower().strip()
    return _PROVIDERS.get(key, _PROVIDERS["kaspi"])
