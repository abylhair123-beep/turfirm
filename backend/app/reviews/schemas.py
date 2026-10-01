from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field


class ReviewCreate(BaseModel):
    tour_id: str = Field(alias="tourId")
    author_name: str = Field(alias="authorName")
    rating: float
    comment: str

    model_config = {
        "populate_by_name": True,
    }


class ReviewResponse(BaseModel):
    id: str
    tour_id: str = Field(alias="tourId")
    author_name: str = Field(alias="authorName")
    rating: float
    comment: str
    created_at: datetime = Field(alias="createdAt")

    model_config = {
        "populate_by_name": True,
        "from_attributes": True,
    }
