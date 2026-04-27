from uuid import UUID

from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user
from app.schemas.recommendation import (
    RecommendRequest,
    RecommendationResponse,
    RecommendationHistoryResponse,
    RatingRequest,
    ParameterUpdateRequest,
)
from app.services import recommendation_service

router = APIRouter(prefix="/recommend", tags=["Recommendations"])


@router.post(
    "/",
    response_model=RecommendationResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Run AI recommendation pipeline for an STL file",
)
def create_recommendation(
    request: RecommendRequest,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rec = recommendation_service.create_recommendation(
        request=request,
        user_id=current_user["user_id"],
        db=db,
    )
    return RecommendationResponse.from_orm_with_alternative(rec)


# NOTE: /history must be declared before /{recommendation_id} — FastAPI matches
# routes in declaration order and would otherwise interpret "history" as a UUID.
@router.get(
    "/history",
    response_model=RecommendationHistoryResponse,
    summary="List all past recommendations for the current user",
)
def get_history(
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    items = recommendation_service.get_history(
        user_id=current_user["user_id"],
        db=db,
    )
    return RecommendationHistoryResponse(
        total=len(items),
        items=[RecommendationResponse.from_orm_with_alternative(r) for r in items],
    )


@router.get(
    "/{recommendation_id}",
    response_model=RecommendationResponse,
    summary="Get a specific recommendation by ID",
)
def get_recommendation(
    recommendation_id: UUID,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # Reuse the rate endpoint's ownership check
    from app.models.recommendation import Recommendation
    from fastapi import HTTPException

    rec = db.query(Recommendation).filter(
        Recommendation.id == recommendation_id,
        Recommendation.user_id == current_user["user_id"],
    ).first()
    if rec is None:
        raise HTTPException(status_code=404, detail="Recommendation not found")
    return RecommendationResponse.from_orm_with_alternative(rec)


@router.patch(
    "/{recommendation_id}/parameters",
    response_model=RecommendationResponse,
    summary="Override technology, material, and print parameters on a recommendation",
)
def update_parameters(
    recommendation_id: UUID,
    body: ParameterUpdateRequest,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rec = recommendation_service.update_parameters(
        recommendation_id=recommendation_id,
        body=body,
        user_id=current_user["user_id"],
        db=db,
    )
    return RecommendationResponse.from_orm_with_alternative(rec)


@router.patch(
    "/{recommendation_id}/rate",
    response_model=RecommendationResponse,
    summary="Submit a 1–5 star rating for a recommendation",
)
def rate_recommendation(
    recommendation_id: UUID,
    body: RatingRequest,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rec = recommendation_service.rate_recommendation(
        recommendation_id=recommendation_id,
        rating=body.rating,
        user_id=current_user["user_id"],
        db=db,
    )
    return RecommendationResponse.from_orm_with_alternative(rec)
