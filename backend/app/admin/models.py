from datetime import datetime, timezone
import uuid
from sqlalchemy import Column, DateTime, Integer, String, Text

from app.database import Base


class FinancialRecord(Base):
    """Журнал финансовых операций платформы Sapar (приходы и расходы)."""
    __tablename__ = "financial_records"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    type = Column(String(20), nullable=False, index=True)  # "income" (приход), "expense" (расход)
    category = Column(String(50), nullable=False, index=True)
    # Категории прихода: "tour_payment", "service_fee", "advertising", "featured_tour"
    # Категории расхода: "agency_payout", "blogger_payout", "acquiring_fee", "marketing", "operational"

    amount = Column(Integer, nullable=False)
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    reference_id = Column(String(100), nullable=True, index=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False, index=True)
