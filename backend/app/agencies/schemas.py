from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field


class AgencyBase(BaseModel):
    name: str
    phone: Optional[str] = None
    email: Optional[str] = None
    address: Optional[str] = None
    description: Optional[str] = None
    logo_url: Optional[str] = Field(default=None, alias="logoUrl")
    bin_iin: Optional[str] = Field(default=None, alias="binIin")
    legal_address: Optional[str] = Field(default=None, alias="legalAddress")
    bank_name: Optional[str] = Field(default=None, alias="bankName")
    bank_iban: Optional[str] = Field(default=None, alias="bankIban")
    bank_bic: Optional[str] = Field(default=None, alias="bankBic")
    contact_person: Optional[str] = Field(default=None, alias="contactPerson")
    telegram_chat_id: Optional[str] = Field(default=None, alias="telegramChatId")

    model_config = {
        "populate_by_name": True,
        "from_attributes": True,
    }


class AgencyCreate(AgencyBase):
    slug: Optional[str] = None


class AgencyUpdate(BaseModel):
    name: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    address: Optional[str] = None
    description: Optional[str] = None
    logo_url: Optional[str] = Field(default=None, alias="logoUrl")
    bin_iin: Optional[str] = Field(default=None, alias="binIin")
    legal_address: Optional[str] = Field(default=None, alias="legalAddress")
    bank_name: Optional[str] = Field(default=None, alias="bankName")
    bank_iban: Optional[str] = Field(default=None, alias="bankIban")
    bank_bic: Optional[str] = Field(default=None, alias="bankBic")
    contact_person: Optional[str] = Field(default=None, alias="contactPerson")
    telegram_chat_id: Optional[str] = Field(default=None, alias="telegramChatId")
    verified: Optional[bool] = None

    model_config = {
        "populate_by_name": True,
    }


class AgencyProfileUpdate(BaseModel):
    name: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    address: Optional[str] = None
    description: Optional[str] = None
    logo_url: Optional[str] = Field(default=None, alias="logoUrl")
    bin_iin: Optional[str] = Field(default=None, alias="binIin")
    legal_address: Optional[str] = Field(default=None, alias="legalAddress")
    bank_name: Optional[str] = Field(default=None, alias="bankName")
    bank_iban: Optional[str] = Field(default=None, alias="bankIban")
    bank_bic: Optional[str] = Field(default=None, alias="bankBic")
    contact_person: Optional[str] = Field(default=None, alias="contactPerson")
    telegram_chat_id: Optional[str] = Field(default=None, alias="telegramChatId")

    model_config = {
        "populate_by_name": True,
    }


class AgencyResponse(AgencyBase):
    id: str
    slug: str
    verified: bool
    rating: float
    reviews_count: int = Field(alias="reviewsCount")
    created_at: datetime = Field(alias="createdAt")

    model_config = {
        "populate_by_name": True,
        "from_attributes": True,
    }


class AgencyBookingStatusUpdate(BaseModel):
    status: str = Field(description="Новый статус: new, confirmed, voucher_issued, completed, cancelled")
    note: Optional[str] = Field(default=None, description="Внутренняя служебная заметка агентства")


class AgencyPayoutRequestCreate(BaseModel):
    amount: int = Field(gt=0, description="Сумма вывода в тенге")
    iban: Optional[str] = Field(default=None, description="IBAN счет (если не заполнен, берется из профиля)")
    bank_name: Optional[str] = Field(default=None, alias="bankName")
    comment: Optional[str] = None

    model_config = {
        "populate_by_name": True,
    }


class AgencyPayoutResponse(BaseModel):
    id: str
    amount: int
    iban: str
    bank_name: Optional[str] = Field(default=None, alias="bankName")
    status: str
    comment: Optional[str] = None
    created_at: datetime = Field(alias="createdAt")
    processed_at: Optional[datetime] = Field(default=None, alias="processedAt")

    model_config = {
        "populate_by_name": True,
        "from_attributes": True,
    }


class AgencyFinanceSummaryResponse(BaseModel):
    total_sales_kzt: int = Field(alias="totalSalesKzt")
    commission_rate: float = Field(alias="commissionRate")
    total_commission_earned: int = Field(alias="totalCommissionEarned")
    paid_out_kzt: int = Field(alias="paidOutKzt")
    pending_payout_kzt: int = Field(alias="pendingPayoutKzt")
    available_balance_kzt: int = Field(alias="availableBalanceKzt")
    bank_iban: Optional[str] = Field(default=None, alias="bankIban")
    bank_name: Optional[str] = Field(default=None, alias="bankName")
    payout_history: List[AgencyPayoutResponse] = Field(default_factory=list, alias="payoutHistory")

    model_config = {
        "populate_by_name": True,
    }
