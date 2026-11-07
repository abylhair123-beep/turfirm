from datetime import datetime
from typing import Dict, List, Optional
from pydantic import BaseModel, ConfigDict, Field


class CallLogCreate(BaseModel):
    target_type: str = Field("customer", description="customer или agency")
    target_name: str = Field(..., description="ФИО клиента или название агентства")
    target_phone: str = Field(..., description="Номер телефона для звонка")
    direction: str = Field("outbound", description="outbound или inbound")
    booking_id: Optional[str] = Field(None, description="ID связанного бронирования")
    user_id: Optional[str] = Field(None, description="ID клиента платформы")
    agency_id: Optional[str] = Field(None, description="ID турагентства")
    status: str = Field("successful", description="successful, no_answer, busy, callback_needed, wrong_number, declined")
    duration_seconds: int = Field(0, ge=0, description="Длительность разговора в секундах")
    notes: Optional[str] = Field(None, description="Заметки менеджера о результатах звонка")
    scheduled_callback_at: Optional[datetime] = Field(None, description="Время запланированного перезвона")
    telephony_provider: str = Field("manual", description="manual, mango, zadarma, sipuni, simulator")
    recording_url: Optional[str] = Field(None, description="Ссылка на аудиозапись звонка")
    external_call_id: Optional[str] = Field(None, description="Внешний ID звонка от АТС")


class CallLogUpdate(BaseModel):
    status: Optional[str] = None
    duration_seconds: Optional[int] = None
    notes: Optional[str] = None
    scheduled_callback_at: Optional[datetime] = None
    recording_url: Optional[str] = None


class CallLogResponse(BaseModel):
    id: str
    direction: str
    target_type: str
    target_name: str
    target_phone: str
    booking_id: Optional[str] = None
    user_id: Optional[str] = None
    agency_id: Optional[str] = None
    manager_id: Optional[str] = None
    manager_name: Optional[str] = None
    tour_title: Optional[str] = None
    status: str
    duration_seconds: int
    notes: Optional[str] = None
    scheduled_callback_at: Optional[datetime] = None
    telephony_provider: str
    recording_url: Optional[str] = None
    external_call_id: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class CallQueueItem(BaseModel):
    id: str  # booking_id or agency_id
    target_type: str  # "customer" or "agency"
    target_name: str
    target_phone: str
    tour_title: Optional[str] = None
    booking_id: Optional[str] = None
    booking_status: Optional[str] = None
    total_price: Optional[int] = None
    priority: str = "normal"  # "high", "normal", "callback"
    last_call_at: Optional[datetime] = None
    last_call_status: Optional[str] = None
    last_call_notes: Optional[str] = None
    scheduled_callback_at: Optional[datetime] = None
    reason: str  # "Новая бронь", "Запланирован перезвон", "Партнёрское агентство"


class CallStatsResponse(BaseModel):
    total_calls: int
    calls_today: int
    successful_calls: int
    answer_rate_pct: float
    avg_duration_seconds: int
    pending_callbacks_count: int
    status_breakdown: Dict[str, int]
    target_type_breakdown: Dict[str, int]


class VoipWebhookPayload(BaseModel):
    event: str = Field(..., description="call_started, call_answered, call_ended")
    external_call_id: str
    caller_phone: str
    callee_phone: str
    direction: str = "outbound"
    status: str = "successful"
    duration_seconds: int = 0
    recording_url: Optional[str] = None
    provider: str = "voip_gateway"


class SimulateVoipCallRequest(BaseModel):
    target_phone: str
    target_name: str
    target_type: str = "customer"
    booking_id: Optional[str] = None
    agency_id: Optional[str] = None
    simulated_outcome: str = "successful"  # "successful", "no_answer", "busy"
    notes: Optional[str] = None
