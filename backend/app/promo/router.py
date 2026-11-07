from datetime import datetime, timezone
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.promo.models import PromoCode
from app.promo.schemas import PromoValidateRequest, PromoValidateResponse

router = APIRouter(prefix="/promo", tags=["Промокоды"])


@router.post("/validate", response_model=PromoValidateResponse)
def validate_promo(payload: PromoValidateRequest, db: Session = Depends(get_db)):
    """Проверяет промокод и считает скидку для указанной суммы."""
    code = payload.code.strip().upper()
    amount = payload.amount

    def fail(message: str) -> PromoValidateResponse:
        return PromoValidateResponse(
            valid=False, code=code, discountPercent=0, discountAmount=0,
            finalAmount=amount, message=message,
        )

    if not code:
        return fail("Введите промокод")

    promo = db.query(PromoCode).filter(PromoCode.code == code).first()
    if not promo or not promo.is_active:
        return fail("Промокод не найден или больше не действует")

    if promo.expires_at is not None:
        expires = promo.expires_at
        if expires.tzinfo is None:
            expires = expires.replace(tzinfo=timezone.utc)
        if expires < datetime.now(timezone.utc):
            return fail("Срок действия промокода истёк")

    discount_amount = round(amount * promo.discount_percent / 100)
    final_amount = max(0, amount - discount_amount)
    return PromoValidateResponse(
        valid=True,
        code=code,
        discountPercent=promo.discount_percent,
        discountAmount=discount_amount,
        finalAmount=final_amount,
        message=f"Промокод применён: −{promo.discount_percent}%",
    )
