from datetime import datetime, timedelta, timezone
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.admin.models import FinancialRecord
from app.admin.schemas import (
    AuditLogItemResponse,
    AuditLogListResponse,
    CategoryBreakdown,
    FinancialChartPoint,
    FinancialRecordCreate,
    FinancialRecordResponse,
    FinancialSummaryResponse,
)
from app.auth.models import User
from app.bookings.models import Booking
from app.core.audit import AuditLog
from app.database import get_db
from app.dependencies import get_current_admin
from app.referrals.models import ReferralPayout

router = APIRouter(prefix="/admin/finances", tags=["Админ-панель: Финансовый баланс"])
audit_router = APIRouter(prefix="/admin/audit-logs", tags=["Админ-панель: Аудит безопасности"])


def _normalize_dt(dt: Optional[datetime]) -> datetime:
    if dt is None:
        return datetime.min
    if dt.tzinfo is not None:
        return dt.astimezone(timezone.utc).replace(tzinfo=None)
    return dt


def _get_start_date(period: str) -> Optional[datetime]:
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    if period == "today":
        return now.replace(hour=0, minute=0, second=0, microsecond=0)
    elif period == "week":
        return now - timedelta(days=7)
    elif period == "month":
        return now - timedelta(days=30)
    return None  # "all"


@router.get("/summary", response_model=FinancialSummaryResponse)
def get_financial_summary(
    period: str = Query("all", description="Период: today, week, month, all"),
    current_admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """Сводный финансовый отчёт для администрации: приходы, расходы, чистая прибыль и аналитика."""
    start_date = _get_start_date(period)

    # 1. Загрузка бронирований
    bookings_query = db.query(Booking).filter(Booking.status.in_(["paid", "confirmed", "completed"]))
    if start_date:
        bookings_query = bookings_query.filter(Booking.created_at >= start_date)
    bookings = bookings_query.all()

    # 2. Загрузка ручных проводок (реклама, маркетинг, операционные расходы)
    records_query = db.query(FinancialRecord)
    if start_date:
        records_query = records_query.filter(FinancialRecord.created_at >= start_date)
    records = records_query.all()

    # 3. Загрузка выплат блогерам
    payouts_query = db.query(ReferralPayout).filter(ReferralPayout.status.in_(["pending", "completed"]))
    if start_date:
        payouts_query = payouts_query.filter(ReferralPayout.created_at >= start_date)
    payouts = payouts_query.all()

    # --- Подсчёт доходов (Приход) ---
    gross_tours_income = sum(b.tour_price * b.guests_count for b in bookings)
    platform_service_fees = sum(b.service_fee for b in bookings)

    ad_revenue = sum(r.amount for r in records if r.type == "income" and r.category == "advertising")
    other_income = sum(r.amount for r in records if r.type == "income" and r.category != "advertising")

    total_income = gross_tours_income + platform_service_fees + ad_revenue + other_income

    # --- Подсчёт расходов (Расход) ---
    # Выплаты турагентствам: стоимость туров за вычетом комиссии платформы (7%)
    agency_payouts = int(gross_tours_income * 0.93)
    blogger_rewards = sum(b.referral_reward or 0 for b in bookings) + sum(p.amount for p in payouts)
    acquiring_fees = int((gross_tours_income + platform_service_fees) * 0.015)  # 1.5% эквайринг Kaspi/банки

    marketing_expenses = sum(r.amount for r in records if r.type == "expense" and r.category in ["marketing", "promo"])
    operational_expenses = sum(r.amount for r in records if r.type == "expense" and r.category not in ["marketing", "promo"])

    total_expense = agency_payouts + blogger_rewards + acquiring_fees + marketing_expenses + operational_expenses

    # --- Итог (Чистая прибыль) ---
    net_profit = total_income - total_expense
    margin = round((net_profit / total_income * 100), 1) if total_income > 0 else 0.0

    # --- Структура доходов ---
    income_breakdown: List[CategoryBreakdown] = []
    if total_income > 0:
        income_breakdown = [
            CategoryBreakdown(
                category="tour_payments",
                label="Оплаты туров клиентами",
                amount=gross_tours_income,
                percentage=round((gross_tours_income / total_income * 100), 1),
            ),
            CategoryBreakdown(
                category="service_fee",
                label="Сервисный сбор Sapar",
                amount=platform_service_fees,
                percentage=round((platform_service_fees / total_income * 100), 1),
            ),
            CategoryBreakdown(
                category="advertising",
                label="Реклама и спонсорские баннеры",
                amount=ad_revenue,
                percentage=round((ad_revenue / total_income * 100), 1),
            ),
        ]
        if other_income > 0:
            income_breakdown.append(
                CategoryBreakdown(
                    category="other_income",
                    label="Прочие доходы",
                    amount=other_income,
                    percentage=round((other_income / total_income * 100), 1),
                )
            )

    # --- Структура расходов ---
    expense_breakdown: List[CategoryBreakdown] = []
    if total_expense > 0:
        expense_breakdown = [
            CategoryBreakdown(
                category="agency_payouts",
                label="Выплаты турагентствам (нетто)",
                amount=agency_payouts,
                percentage=round((agency_payouts / total_expense * 100), 1),
            ),
            CategoryBreakdown(
                category="blogger_payouts",
                label="Бонусы блогерам и рефералам",
                amount=blogger_rewards,
                percentage=round((blogger_rewards / total_expense * 100), 1),
            ),
            CategoryBreakdown(
                category="acquiring_fee",
                label="Банковский эквайринг (1.5%)",
                amount=acquiring_fees,
                percentage=round((acquiring_fees / total_expense * 100), 1),
            ),
        ]
        if marketing_expenses > 0:
            expense_breakdown.append(
                CategoryBreakdown(
                    category="marketing",
                    label="Маркетинг и реклама",
                    amount=marketing_expenses,
                    percentage=round((marketing_expenses / total_expense * 100), 1),
                )
            )
        if operational_expenses > 0:
            expense_breakdown.append(
                CategoryBreakdown(
                    category="operational",
                    label="Серверы и операционные расходы",
                    amount=operational_expenses,
                    percentage=round((operational_expenses / total_expense * 100), 1),
                )
            )

    # --- График динамики по дням (последние 7 дней) ---
    chart_points: List[FinancialChartPoint] = []
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    for i in range(6, -1, -1):
        day = now - timedelta(days=i)
        day_str = day.strftime("%d.%m")
        day_start = day.replace(hour=0, minute=0, second=0, microsecond=0)
        day_end = day_start + timedelta(days=1)

        day_bookings = [b for b in bookings if day_start <= _normalize_dt(b.created_at) < day_end]
        day_records_inc = [r for r in records if r.type == "income" and day_start <= _normalize_dt(r.created_at) < day_end]
        day_records_exp = [r for r in records if r.type == "expense" and day_start <= _normalize_dt(r.created_at) < day_end]

        day_inc = sum(b.total_price for b in day_bookings) + sum(r.amount for r in day_records_inc)
        day_tours_gross = sum(b.tour_price * b.guests_count for b in day_bookings)
        day_exp = int(day_tours_gross * 0.93) + sum(b.referral_reward or 0 for b in day_bookings) + sum(r.amount for r in day_records_exp)
        day_net = day_inc - day_exp

        chart_points.append(
            FinancialChartPoint(
                date=day_str,
                income=day_inc,
                expense=day_exp,
                net=day_net,
            )
        )

    # --- Последние финансовые операции ---
    recent_transactions: List[FinancialRecordResponse] = []

    # Добавляем брони как операции прихода
    for b in bookings[:15]:
        recent_transactions.append(
            FinancialRecordResponse(
                id=f"tx-bk-{b.id}",
                type="income",
                category="tour_payment",
                amount=b.total_price,
                title=f"Оплата тура: {b.tour.title if b.tour else 'Тур Sapar'}",
                description=f"Клиент: {b.customer_name} ({b.payment_method})",
                referenceId=b.id,
                createdAt=b.created_at,
            )
        )

    # Добавляем записи из FinancialRecord
    for r in records[:15]:
        recent_transactions.append(
            FinancialRecordResponse(
                id=r.id,
                type=r.type,
                category=r.category,
                amount=r.amount,
                title=r.title,
                description=r.description,
                referenceId=r.reference_id,
                createdAt=r.created_at,
            )
        )

    # Добавляем выплаты блогерам
    for p in payouts[:10]:
        recent_transactions.append(
            FinancialRecordResponse(
                id=f"tx-pay-{p.id}",
                type="expense",
                category="blogger_payout",
                amount=p.amount,
                title=f"Выплата блогеру ({p.payment_details})",
                description=f"Статус заявки: {p.status}",
                referenceId=p.id,
                createdAt=p.created_at,
            )
        )

    recent_transactions.sort(key=lambda x: _normalize_dt(x.created_at), reverse=True)

    return FinancialSummaryResponse(
        period=period,
        totalIncome=total_income,
        totalExpense=total_expense,
        netProfit=net_profit,
        marginPercentage=margin,
        incomeBreakdown=income_breakdown,
        expenseBreakdown=expense_breakdown,
        chartPoints=chart_points,
        recentTransactions=recent_transactions[:25],
    )


@router.post("/records", response_model=FinancialRecordResponse, status_code=status.HTTP_201_CREATED)
def create_financial_record(
    payload: FinancialRecordCreate,
    current_admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """Внести новую финансовую проводку (рекламный доход, маркетинговый расход, операционный сбор)."""
    if payload.type not in ["income", "expense"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Тип проводки должен быть 'income' (приход) или 'expense' (расход)",
        )
    if payload.amount <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Сумма проводки должна быть положительной",
        )

    record = FinancialRecord(
        type=payload.type,
        category=payload.category,
        amount=payload.amount,
        title=payload.title,
        description=payload.description,
        reference_id=payload.reference_id,
    )
    db.add(record)
    db.commit()
    db.refresh(record)

    return FinancialRecordResponse(
        id=record.id,
        type=record.type,
        category=record.category,
        amount=record.amount,
        title=record.title,
        description=record.description,
        referenceId=record.reference_id,
        createdAt=record.created_at,
    )


# ==================== АУДИТ БЕЗОПАСНОСТИ ====================

@audit_router.get("", response_model=AuditLogListResponse)
def get_audit_logs(
    action: Optional[str] = Query(None, description="Фильтр по действию (например LOGIN_SUCCESS, 2FA_ENABLED)"),
    status: Optional[str] = Query(None, description="Фильтр по статусу (SUCCESS, WARNING, FAILED)"),
    user_id: Optional[str] = Query(None, description="Фильтр по ID пользователя"),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    current_admin: User = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """Возвращает журнал аудита безопасности с поддержкой пагинации и фильтрации."""
    query = db.query(AuditLog)
    if action:
        query = query.filter(AuditLog.action == action)
    if status:
        query = query.filter(AuditLog.status == status)
    if user_id:
        query = query.filter(AuditLog.user_id == user_id)

    total = query.count()
    items = query.order_by(AuditLog.created_at.desc()).offset(skip).limit(limit).all()

    return AuditLogListResponse(
        items=[
            AuditLogItemResponse(
                id=item.id,
                createdAt=item.created_at,
                userId=item.user_id,
                userEmail=item.user_email,
                userRole=item.user_role,
                ipAddress=item.ip_address,
                action=item.action,
                resource=item.resource,
                status=item.status,
                details=item.details,
            )
            for item in items
        ],
        total=total,
        skip=skip,
        limit=limit,
    )
