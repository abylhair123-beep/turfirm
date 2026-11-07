from typing import Optional
from pydantic import BaseModel


class SuggestItem(BaseModel):
    """Одна подсказка в выпадающем списке поиска."""

    type: str  # 'destination' | 'tour' | 'agency' | 'category'
    text: str
    subtitle: Optional[str] = None
    tour_id: Optional[str] = None
