from datetime import datetime, timezone
import random
import re
import string
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy.orm import Session

from app.auth.models import User
from app.bookings.models import Booking
from app.database import get_db
from app.dependencies import get_current_user
from app.referrals.models import ReferralClick, ReferralPartner, ReferralPayout
from app.referrals.schemas import (
    PayoutRequest,
    PayoutResponse,
    ReferralBookingItem,
    ReferralCampaignCreate,
    ReferralCheckResponse,
    ReferralClickRequest,
    ReferralClickResponse,
    ReferralPartnerResponse,
    ReferralStatsResponse,
)

router = APIRouter(prefix="/referrals", tags=["Реферальная программа для блогеров"])


def _sanitize_code(raw: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9_-]", "", raw).upper()
    return cleaned[:30]


def _generate_unique_code(db: Session, base_name: str) -> str:
    # Очищаем имя от кириллицы / спецсимволов для латинского промокода
    slug = re.sub(r"[^A-Za-z0-9]", "", base_name).upper()
    if not slug:
        slug = "SAPAR"
    slug = slug[:10]

    for _ in range(10):
        suffix = "".join(random.choices(string.digits + string.ascii_uppercase, k=4))
        candidate = f"{slug}_{suffix}"
        exists = db.query(ReferralPartner).filter(ReferralPartner.code == candidate).first()
        if not exists:
            return candidate

    # fallback
    return f"SAPAR_{random.randint(100000, 999999)}"


def _to_partner_response(partner: ReferralPartner) -> ReferralPartnerResponse:
    # Базовый URL для реферальной ссылки
    referral_url = f"https://sapar.kz/?ref={partner.code}"
    return ReferralPartnerResponse(
        id=partner.id,
        userId=partner.user_id,
        code=partner.code,
        campaignName=partner.campaign_name,
        commissionRate=partner.commission_rate,
        fixedReward=partner.fixed_reward,
        clicksCount=partner.clicks_count,
        bookingsCount=partner.bookings_count,
        totalEarned=partner.total_earned,
        balance=partner.balance,
        referralUrl=referral_url,
        isActive=partner.is_active,
        createdAt=partner.created_at,
    )


@router.post("/campaigns", response_model=ReferralPartnerResponse, status_code=status.HTTP_201_CREATED)
def create_campaign(
    payload: ReferralCampaignCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Создать новую реферальную ссылку / промокод для блогера."""
    if payload.code and payload.code.strip():
        code = _sanitize_code(payload.code.strip())
        if len(code) < 3:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Реферальный код должен содержать минимум 3 символа (буквы или цифры)",
            )
        exists = db.query(ReferralPartner).filter(ReferralPartner.code == code).first()
        if exists:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Промокод '{code}' уже занят другим партнером. Попробуйте другой вариант.",
            )
    else:
        code = _generate_unique_code(db, current_user.full_name)

    campaign_name = payload.campaign_name.strip() if payload.campaign_name else "Основная кампания"

    partner = ReferralPartner(
        user_id=current_user.id,
        code=code,
        campaign_name=campaign_name,
        commission_rate=payload.commission_rate or 3.0,
        fixed_reward=0,
        clicks_count=0,
        bookings_count=0,
        total_earned=0,
        balance=0,
        is_active=True,
    )
    db.add(partner)
    db.commit()
    db.refresh(partner)

    return _to_partner_response(partner)


@router.get("/me", response_model=List[ReferralPartnerResponse])
def get_my_campaigns(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Список активных ссылок и промокодов текущего блогера/партнера."""
    campaigns = (
        db.query(ReferralPartner)
        .filter(ReferralPartner.user_id == current_user.id)
        .order_by(ReferralPartner.created_at.desc())
        .all()
    )

    # Если кампаний еще нет — автоматически создаем первую кампанию для пользователя
    if not campaigns:
        initial_code = _generate_unique_code(db, current_user.full_name)
        new_partner = ReferralPartner(
            user_id=current_user.id,
            code=initial_code,
            campaign_name="Основная ссылка",
            commission_rate=3.0,
            fixed_reward=0,
            clicks_count=0,
            bookings_count=0,
            total_earned=0,
            balance=0,
            is_active=True,
        )
        db.add(new_partner)
        db.commit()
        db.refresh(new_partner)
        campaigns = [new_partner]

    return [_to_partner_response(c) for c in campaigns]


@router.get("/stats", response_model=ReferralStatsResponse)
def get_referral_stats(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Сводная статистика блогера: переходы, брони, начисленные бонусы и история."""
    campaigns = (
        db.query(ReferralPartner)
        .filter(ReferralPartner.user_id == current_user.id)
        .order_by(ReferralPartner.created_at.desc())
        .all()
    )

    if not campaigns:
        # Автосоздание стартовой ссылки
        initial_code = _generate_unique_code(db, current_user.full_name)
        new_partner = ReferralPartner(
            user_id=current_user.id,
            code=initial_code,
            campaign_name="Основная ссылка",
            commission_rate=3.0,
            fixed_reward=0,
            clicks_count=0,
            bookings_count=0,
            total_earned=0,
            balance=0,
            is_active=True,
        )
        db.add(new_partner)
        db.commit()
        db.refresh(new_partner)
        campaigns = [new_partner]

    campaign_ids = [c.id for c in campaigns]
    total_clicks = sum(c.clicks_count for c in campaigns)
    total_bookings = sum(c.bookings_count for c in campaigns)
    conversion_rate = round((total_bookings / total_clicks * 100), 2) if total_clicks > 0 else 0.0
    total_earned = sum(c.total_earned for c in campaigns)
    balance = sum(c.balance for c in campaigns)

    # Список последних бронирований по реферальным ссылкам
    recent_bookings_db = (
        db.query(Booking)
        .filter(Booking.referral_partner_id.in_(campaign_ids))
        .order_by(Booking.created_at.desc())
        .limit(20)
        .all()
    )

    recent_items = [
        ReferralBookingItem(
            id=b.id,
            bookingId=b.id,
            tourTitle=b.tour.title if b.tour else "Тур Sapar",
            customerName=b.customer_name,
            tourPrice=b.tour_price,
            reward=b.referral_reward or 0,
            status=b.status,
            createdAt=b.created_at,
        )
        for b in recent_bookings_db
    ]

    return ReferralStatsResponse(
        totalClicks=total_clicks,
        totalBookings=total_bookings,
        conversionRate=conversion_rate,
        totalEarned=total_earned,
        balance=balance,
        campaigns=[_to_partner_response(c) for c in campaigns],
        recentBookings=recent_items,
    )


@router.post("/click", response_model=ReferralClickResponse)
def track_click(
    payload: ReferralClickRequest,
    request: Request,
    db: Session = Depends(get_db),
):
    """Публичный эндпоинт: трекинг перехода по реферальной ссылке."""
    code = payload.code.strip().upper()
    partner = db.query(ReferralPartner).filter(ReferralPartner.code == code, ReferralPartner.is_active.is_(True)).first()
    if not partner:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Реферальная ссылка недействительна",
        )

    partner.clicks_count += 1

    ip_address = request.client.host if request.client else None
    user_agent = request.headers.get("user-agent")[:255] if request.headers.get("user-agent") else None

    click = ReferralClick(
        partner_id=partner.id,
        code=code,
        tour_id=payload.tour_id,
        ip_address=ip_address,
        user_agent=user_agent,
        referrer_url=payload.referrer_url,
    )
    db.add(click)
    db.commit()

    return ReferralClickResponse(
        status="ok",
        code=code,
        clicksCount=partner.clicks_count,
    )


@router.get("/check/{code}", response_model=ReferralCheckResponse)
def check_code(
    code: str,
    db: Session = Depends(get_db),
):
    """Проверка промокода блогера при оформлении бронирования клиентом."""
    clean_code = code.strip().upper()
    partner = db.query(ReferralPartner).filter(ReferralPartner.code == clean_code, ReferralPartner.is_active.is_(True)).first()
    if not partner:
        return ReferralCheckResponse(
            valid=False,
            code=clean_code,
            message="Промокод не найден или срок его действия истек",
        )

    blogger_name = partner.user.full_name if partner.user else "Блогер Sapar"
    return ReferralCheckResponse(
        valid=True,
        code=clean_code,
        campaignName=partner.campaign_name,
        bloggerName=blogger_name,
        discountPercent=partner.commission_rate or 3.0,
        message=f"Промокод активирован! Скидка от блогера {blogger_name}",
    )


@router.post("/payout", response_model=PayoutResponse)
def request_payout(
    payload: PayoutRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Запрос блогера на вывод накопленных партнерских средств."""
    if payload.amount < 1000:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Минимальная сумма для вывода — 1 000 ₸",
        )

    campaigns = (
        db.query(ReferralPartner)
        .filter(ReferralPartner.user_id == current_user.id, ReferralPartner.is_active.is_(True))
        .all()
    )
    total_balance = sum(c.balance for c in campaigns)

    if payload.amount > total_balance:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Недостаточно средств. Ваш баланс: {total_balance} ₸, запрошено: {payload.amount} ₸",
        )

    # Списываем сумму с кампаний блогера
    remaining_to_deduct = payload.amount
    primary_campaign = campaigns[0]
    for c in campaigns:
        if c.balance > 0:
            deduct = min(c.balance, remaining_to_deduct)
            c.balance -= deduct
            remaining_to_deduct -= deduct
            db.add(c)
            if remaining_to_deduct == 0:
                break

    payout = ReferralPayout(
        partner_id=primary_campaign.id,
        amount=payload.amount,
        payment_details=payload.payment_details,
        status="pending",
    )
    db.add(payout)
    db.commit()
    db.refresh(payout)

    new_balance = total_balance - payload.amount

    return PayoutResponse(
        id=payout.id,
        amount=payout.amount,
        status="pending",
        message="Заявка на выплату успешно принята! Средства поступят в течение 24 часов на указанные реквизиты.",
        remainingBalance=new_balance,
    )
