from datetime import datetime
from typing import Any, Dict, Optional
from pydantic import BaseModel, Field


class PaymentInitiateRequest(BaseModel):
    booking_id: str = Field(alias="bookingId")
    payment_method: str = Field(default="Kaspi Pay", alias="paymentMethod")
    customer_phone: Optional[str] = Field(default=None, alias="customerPhone")
    customer_email: Optional[str] = Field(default=None, alias="customerEmail")
    customer_name: Optional[str] = Field(default=None, alias="customerName")
    return_url: Optional[str] = Field(default=None, alias="returnUrl")

    model_config = {
        "populate_by_name": True,
    }


class PaymentInitiateResponse(BaseModel):
    payment_id: str = Field(alias="paymentId")
    booking_id: str = Field(alias="bookingId")
    amount: int
    currency: str = "KZT"
    provider: str
    status: str
    payment_url: Optional[str] = Field(default=None, alias="paymentUrl")
    deeplink_url: Optional[str] = Field(default=None, alias="deeplinkUrl")
    qr_code_data: Optional[str] = Field(default=None, alias="qrCodeData")
    qr_code_url: Optional[str] = Field(default=None, alias="qrCodeUrl")
    created_at: datetime = Field(alias="createdAt")

    model_config = {
        "populate_by_name": True,
        "from_attributes": True,
    }


class PaymentStatusResponse(BaseModel):
    payment_id: str = Field(alias="paymentId")
    booking_id: str = Field(alias="bookingId")
    amount: int
    currency: str = "KZT"
    provider: str
    status: str
    external_transaction_id: Optional[str] = Field(default=None, alias="externalTransactionId")
    created_at: datetime = Field(alias="createdAt")
    updated_at: datetime = Field(alias="updatedAt")

    model_config = {
        "populate_by_name": True,
        "from_attributes": True,
    }


class KaspiWebhookPayload(BaseModel):
    order_id: str = Field(alias="orderId")
    transaction_id: Optional[str] = Field(default=None, alias="transactionId")
    status: str  # "paid", "cancelled", "failed"
    amount: Optional[int] = None
    signature: Optional[str] = None

    model_config = {
        "populate_by_name": True,
    }


class KaspiWebhookResponse(BaseModel):
    result: str = "ok"
    order_id: str = Field(alias="orderId")
    status: str

    model_config = {
        "populate_by_name": True,
    }


class HalykWebhookPayload(BaseModel):
    invoice_id: str = Field(alias="invoiceId")
    order_id: Optional[str] = Field(default=None, alias="orderId")
    status: str  # "paid", "success", "confirmed", "failed", "cancelled"
    amount: int
    currency: str = "KZT"
    reference: Optional[str] = None
    approval_code: Optional[str] = Field(default=None, alias="approvalCode")
    signature: Optional[str] = None

    model_config = {
        "populate_by_name": True,
    }


class HalykWebhookResponse(BaseModel):
    result: str = "ok"
    invoice_id: str = Field(alias="invoiceId")
    status: str

    model_config = {
        "populate_by_name": True,
    }


class PaymentRefundRequest(BaseModel):
    reason: str = Field(default="Запрос на возврат средств клиентом")
    amount: Optional[int] = Field(default=None, description="Частичный или полный возврат (в тенге)")


class PaymentRefundResponse(BaseModel):
    payment_id: str = Field(alias="paymentId")
    booking_id: str = Field(alias="bookingId")
    status: str
    refunded_amount: int = Field(alias="refundedAmount")
    reason: str
    processed_at: datetime = Field(alias="processedAt")

    model_config = {
        "populate_by_name": True,
    }
