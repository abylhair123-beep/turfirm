from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field


class FinancialRecordCreate(BaseModel):
    type: str  # "income" или "expense"
    category: str
    amount: int
    title: str
    description: Optional[str] = None
    reference_id: Optional[str] = Field(default=None, alias="referenceId")

    model_config = {
        "populate_by_name": True,
    }


class FinancialRecordResponse(BaseModel):
    id: str
    type: str
    category: str
    amount: int
    title: str
    description: Optional[str] = None
    reference_id: Optional[str] = Field(default=None, alias="referenceId")
    created_at: datetime = Field(alias="createdAt")

    model_config = {
        "populate_by_name": True,
        "from_attributes": True,
    }


class CategoryBreakdown(BaseModel):
    category: str
    label: str
    amount: int
    percentage: float

    model_config = {
        "populate_by_name": True,
    }


class FinancialChartPoint(BaseModel):
    date: str
    income: int
    expense: int
    net: int

    model_config = {
        "populate_by_name": True,
    }


class FinancialSummaryResponse(BaseModel):
    period: str
    total_income: int = Field(alias="totalIncome")
    total_expense: int = Field(alias="totalExpense")
    net_profit: int = Field(alias="netProfit")
    margin_percentage: float = Field(alias="marginPercentage")
    income_breakdown: List[CategoryBreakdown] = Field(alias="incomeBreakdown")
    expense_breakdown: List[CategoryBreakdown] = Field(alias="expenseBreakdown")
    chart_points: List[FinancialChartPoint] = Field(alias="chartPoints")
    recent_transactions: List[FinancialRecordResponse] = Field(alias="recentTransactions")

    model_config = {
        "populate_by_name": True,
    }


class AuditLogItemResponse(BaseModel):
    id: str
    created_at: datetime = Field(alias="createdAt")
    user_id: Optional[str] = Field(default=None, alias="userId")
    user_email: Optional[str] = Field(default=None, alias="userEmail")
    user_role: Optional[str] = Field(default=None, alias="userRole")
    ip_address: Optional[str] = Field(default=None, alias="ipAddress")
    action: str
    resource: str
    status: str
    details: Optional[str] = None

    model_config = {
        "populate_by_name": True,
        "from_attributes": True,
    }


class AuditLogListResponse(BaseModel):
    items: List[AuditLogItemResponse]
    total: int
    skip: int
    limit: int
