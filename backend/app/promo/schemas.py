from typing import Optional
from pydantic import BaseModel, Field


class PromoValidateRequest(BaseModel):
    code: str
    amount: int = Field(ge=0, description="Сумма заказа, к которой применяется промокод")


class PromoValidateResponse(BaseModel):
    valid: bool
    code: str
    discount_percent: int = Field(default=0, alias="discountPercent")
    discount_amount: int = Field(default=0, alias="discountAmount")
    final_amount: int = Field(default=0, alias="finalAmount")
    message: str

    model_config = {"populate_by_name": True}
