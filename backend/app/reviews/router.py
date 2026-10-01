from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.auth.models import User
from app.database import get_db
from app.dependencies import get_current_user_optional
from app.reviews.models import Review
from app.reviews.schemas import ReviewCreate, ReviewResponse
from app.tours.models import Tour

router = APIRouter(prefix="/reviews", tags=["Отзывы"])


def _review_to_response(r: Review) -> ReviewResponse:
    return ReviewResponse(
        id=r.id,
        tourId=r.tour_id,
        authorName=r.author_name,
        rating=r.rating,
        comment=r.comment,
        createdAt=r.created_at,
    )


@router.get("/tours/{tour_id}", response_model=List[ReviewResponse])
def get_tour_reviews(tour_id: str, db: Session = Depends(get_db)):
    reviews = db.query(Review).filter(Review.tour_id == tour_id).order_by(Review.created_at.desc()).all()
    return [_review_to_response(r) for r in reviews]


@router.post("/tours/{tour_id}", response_model=ReviewResponse, status_code=status.HTTP_201_CREATED)
def add_review(
    tour_id: str,
    review_in: ReviewCreate,
    current_user: Optional[User] = Depends(get_current_user_optional),
    db: Session = Depends(get_db),
):
    tour = db.query(Tour).filter(Tour.id == tour_id).first()
    if not tour:
        raise HTTPException(status_code=404, detail="Тур не найден")

    review = Review(
        tour_id=tour.id,
        user_id=current_user.id if current_user else None,
        author_name=review_in.author_name or (current_user.full_name if current_user else "Гость"),
        rating=review_in.rating,
        comment=review_in.comment,
    )
    db.add(review)

    # Recalculate tour rating and reviews count
    current_reviews = db.query(Review).filter(Review.tour_id == tour.id).all()
    total_reviews = len(current_reviews) + 1
    new_avg = round((sum(r.rating for r in current_reviews) + review_in.rating) / total_reviews, 1)

    tour.rating = new_avg
    tour.reviews_count = total_reviews

    db.commit()
    db.refresh(review)
    return _review_to_response(review)
