from typing import List, Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.database import get_db
from app.search.schemas import SuggestItem
from app.tours.models import Tour

router = APIRouter(prefix="/search", tags=["Поиск"])


@router.get("/suggest", response_model=List[SuggestItem])
def suggest(
    q: str = Query("", description="Строка, которую вводит пользователь"),
    limit: int = Query(8, ge=1, le=20),
    db: Session = Depends(get_db),
):
    """Автоподсказки по мере ввода (как в Kaspi): направления, туры,
    турагентства и категории, подходящие под введённый текст."""
    term = q.strip()
    if len(term) < 1:
        return []

    pattern = f"%{term}%"
    items: List[SuggestItem] = []
    seen = set()

    def add(type_: str, text: Optional[str], subtitle: Optional[str] = None, tour_id: Optional[str] = None):
        if not text:
            return
        key = (type_, text.lower())
        if key in seen:
            return
        seen.add(key)
        items.append(SuggestItem(type=type_, text=text, subtitle=subtitle, tour_id=tour_id))

    active = Tour.is_active == True  # noqa: E712

    # Направления (города / страны)
    for (dest,) in (
        db.query(Tour.destination)
        .filter(active, Tour.destination.ilike(pattern))
        .distinct()
        .limit(limit)
        .all()
    ):
        add("destination", dest)

    # Конкретные туры по названию
    for tour in (
        db.query(Tour)
        .filter(active, Tour.title.ilike(pattern))
        .order_by(Tour.rating.desc())
        .limit(limit)
        .all()
    ):
        add("tour", tour.title, subtitle=tour.destination, tour_id=tour.id)

    # Турагентства
    for (name,) in (
        db.query(Tour.agency_name)
        .filter(active, Tour.agency_name.ilike(pattern))
        .distinct()
        .limit(limit)
        .all()
    ):
        add("agency", name)

    # Категории
    for (cat,) in (
        db.query(Tour.category)
        .filter(active, Tour.category.ilike(pattern))
        .distinct()
        .limit(limit)
        .all()
    ):
        add("category", cat)

    # Подсказки, начинающиеся с введённого текста, показываем выше
    term_low = term.lower()
    items.sort(key=lambda it: 0 if it.text.lower().startswith(term_low) else 1)
    return items[:limit]


@router.get("/popular", response_model=List[SuggestItem])
def popular(
    limit: int = Query(8, ge=1, le=20),
    db: Session = Depends(get_db),
):
    """Популярные направления — показываем, когда строка поиска пустая."""
    rows = (
        db.query(Tour.destination, func.count(Tour.id).label("cnt"))
        .filter(Tour.is_active == True)  # noqa: E712
        .group_by(Tour.destination)
        .order_by(func.count(Tour.id).desc())
        .limit(limit)
        .all()
    )
    return [SuggestItem(type="destination", text=dest) for dest, _ in rows]
