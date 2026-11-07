from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field


class ReferralCampaignCreate(BaseModel):
    code: Optional[str] = None
    campaign_name: Optional[str] = Field(default="Основная кампания", alias="campaignName")
    commission_rate: Optional[float] = Field(default=3.0, alias="commissionRate")

    model_config = {
        "populate_by_name": True,
    }


class ReferralPartnerResponse(BaseModel):
    id: str
    user_id: str = Field(alias="userId")
    code: str
    campaign_name: str = Field(alias="campaignName")
    commission_rate: float = Field(alias="commissionRate")
    fixed_reward: int = Field(alias="fixedReward")
    clicks_count: int = Field(alias="clicksCount")
    bookings_count: int = Field(alias="bookingsCount")
    total_earned: int = Field(alias="totalEarned")
    balance: int
    referral_url: str = Field(alias="referralUrl")
    is_active: bool = Field(alias="isActive")
    created_at: datetime = Field(alias="createdAt")

    model_config = {
        "populate_by_name": True,
        "from_attributes": True,
    }


class ReferralClickRequest(BaseModel):
    code: str
    tour_id: Optional[str] = Field(default=None, alias="tourId")
    referrer_url: Optional[str] = Field(default=None, alias="referrerUrl")

    model_config = {
        "populate_by_name": True,
    }


class ReferralClickResponse(BaseModel):
    status: str = "ok"
    code: str
    clicks_count: int = Field(alias="clicksCount")

    model_config = {
        "populate_by_name": True,
    }


class ReferralCheckResponse(BaseModel):
    valid: bool
    code: str
    campaign_name: Optional[str] = Field(default=None, alias="campaignName")
    blogger_name: Optional[str] = Field(default=None, alias="bloggerName")
    discount_percent: float = Field(default=3.0, alias="discountPercent")
    message: str

    model_config = {
        "populate_by_name": True,
    }


class ReferralBookingItem(BaseModel):
    id: str
    booking_id: str = Field(alias="bookingId")
    tour_title: str = Field(alias="tourTitle")
    customer_name: str = Field(alias="customerName")
    tour_price: int = Field(alias="tourPrice")
    reward: int
    status: str
    created_at: datetime = Field(alias="createdAt")

    model_config = {
        "populate_by_name": True,
    }


class ReferralStatsResponse(BaseModel):
    total_clicks: int = Field(alias="totalClicks")
    total_bookings: int = Field(alias="totalBookings")
    conversion_rate: float = Field(alias="conversionRate")
    total_earned: int = Field(alias="totalEarned")
    balance: int
    campaigns: List[ReferralPartnerResponse]
    recent_bookings: List[ReferralBookingItem] = Field(default_factory=list, alias="recentBookings")

    model_config = {
        "populate_by_name": True,
    }


class PayoutRequest(BaseModel):
    amount: int
    payment_details: str = Field(alias="paymentDetails")

    model_config = {
        "populate_by_name": True,
    }


class PayoutResponse(BaseModel):
    id: str
    amount: int
    status: str
    message: str
    remaining_balance: int = Field(alias="remainingBalance")

    model_config = {
        "populate_by_name": True,
    }
