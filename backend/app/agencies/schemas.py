from datetime import datetime
from typing import Optional
from pydantic import BaseModel


class AgencyBase(BaseModel):
    name: str
    phone: Optional[str] = None
    email: Optional[str] = None
    address: Optional[str] = None
    description: Optional[str] = None
    logo_url: Optional[str] = None


class AgencyCreate(AgencyBase):
    slug: Optional[str] = None


class AgencyUpdate(BaseModel):
    name: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    address: Optional[str] = None
    description: Optional[str] = None
    logo_url: Optional[str] = None
    verified: Optional[bool] = None


class AgencyResponse(AgencyBase):
    id: str
    slug: str
    verified: bool
    rating: float
    reviews_count: int
    created_at: datetime

    model_config = {"from_attributes": True}
