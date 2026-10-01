from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.auth.models import User
from app.database import get_db
from app.dependencies import get_current_user
from app.favorites.models import Favorite
from app.tours.models import Tour
from app.tours.router import _tour_to_response
from app.tours.schemas import TourResponse

router = APIRouter(prefix="/favorites", tags=["Избранное"])


@router.get("", response_model=List[TourResponse])
def get_user_favorites(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Список избранных туров текущего пользователя."""
    favorites = db.query(Favorite).filter(Favorite.user_id == current_user.id).all()
    tour_ids = [f.tour_id for f in favorites]
    if not tour_ids:
        return []
    tours = db.query(Tour).filter(Tour.id.in_(tour_ids)).all()
    return [_tour_to_response(t) for t in tours]


@router.post("/{tour_id}", status_code=status.HTTP_201_CREATED)
def add_to_favorites(
    tour_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Добавить тур в избранное."""
    tour = db.query(Tour).filter(Tour.id == tour_id).first()
    if not tour:
        raise HTTPException(status_code=404, detail="Тур не найден")

    existing = (
        db.query(Favorite)
        .filter(Favorite.user_id == current_user.id, Favorite.tour_id == tour_id)
        .first()
    )
    if existing:
        return {"status": "ok", "message": "Тур уже в избранном"}

    fav = Favorite(user_id=current_user.id, tour_id=tour.id)
    db.add(fav)
    db.commit()
    return {"status": "ok", "message": "Тур добавлен в избранное"}


@router.delete("/{tour_id}", status_code=status.HTTP_200_OK)
def remove_from_favorites(
    tour_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Удалить тур из избранного."""
    fav = (
        db.query(Favorite)
        .filter(Favorite.user_id == current_user.id, Favorite.tour_id == tour_id)
        .first()
    )
    if fav:
        db.delete(fav)
        db.commit()
    return {"status": "ok", "message": "Тур удален из избранного"}


@router.get("/check/{tour_id}")
def check_favorite(
    tour_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Проверить, находится ли тур в избранном."""
    fav = (
        db.query(Favorite)
        .filter(Favorite.user_id == current_user.id, Favorite.tour_id == tour_id)
        .first()
    )
    return {"tourId": tour_id, "isFavorite": fav is not None}
