import uuid
import logging
from typing import Any
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.recommendation import Recommendation
from app.models.stl_file import STLFile
from app.schemas.recommendation import RecommendRequest

logger = logging.getLogger(__name__)


# ── Stub prediction rules ─────────────────────────────────────────────────────
# TODO Sprint 5: Replace _stub_predict() with real ML model inference.
# Input: geometry features from stl_file + user intent from request.
# Keep the surrounding persistence code in create_recommendation() unchanged.

_BASE_PARAMS: dict[str, dict[str, Any]] = {
    "functional": {
        "technology": "FDM",
        "material": "PETG",
        "technology_confidence": 0.87,
        "material_confidence": 0.83,
        "confidence_tier": "high",
        "layer_height": 0.20,
        "infill_density": 40,
        "print_speed": 50,
        "wall_count": 3,
        "cooling_fan": 80,
        "support_density": 15,
        "cost_score": 65,
        "quality_score": 78,
        "speed_score": 72,
        "alternative": None,
    },
    "decorative": {
        "technology": "FDM",
        "material": "PLA",
        "technology_confidence": 0.91,
        "material_confidence": 0.88,
        "confidence_tier": "high",
        "layer_height": 0.15,
        "infill_density": 20,
        "print_speed": 45,
        "wall_count": 2,
        "cooling_fan": 100,
        "support_density": 10,
        "cost_score": 82,
        "quality_score": 88,
        "speed_score": 70,
        "alternative": None,
    },
    "prototype": {
        "technology": "FDM",
        "material": "PLA",
        "technology_confidence": 0.62,
        "material_confidence": 0.58,
        "confidence_tier": "medium",
        "layer_height": 0.20,
        "infill_density": 15,
        "print_speed": 55,
        "wall_count": 2,
        "cooling_fan": 80,
        "support_density": 10,
        "cost_score": 88,
        "quality_score": 65,
        "speed_score": 82,
        "alternative": {
            "technology": "SLA",
            "material": "Resin-Std",
            "confidence": 0.55,
            "cost_score": 45,
            "quality_score": 92,
            "speed_score": 40,
        },
    },
}


def _stub_predict(request: RecommendRequest) -> dict[str, Any]:
    """
    Deterministic stub prediction based on intended_use and surface_finish.
    Returns a dict of result fields to be persisted in the Recommendation row.
    """
    base = dict(_BASE_PARAMS.get(request.intended_use, _BASE_PARAMS["functional"]))

    # Surface finish modifiers
    lh = base["layer_height"]
    qs = base["quality_score"]
    ss = base["speed_score"]

    if request.surface_finish == "fine":
        lh = round(lh * 0.75, 3)
        qs = min(100, qs + 8)
        # Provide range bars for fine finish (uncertainty in layer height)
        base["layer_height_min"] = round(lh - 0.02, 3)
        base["layer_height_max"] = round(lh + 0.02, 3)
    elif request.surface_finish == "rough":
        lh = round(lh * 1.5, 3)
        ss = min(100, ss + 5)

    base["layer_height"] = lh
    base["quality_score"] = qs
    base["speed_score"] = ss

    base.setdefault("layer_height_min", None)
    base.setdefault("layer_height_max", None)
    base["needs_clarification"] = False
    base["clarification_question"] = None
    base["clarification_field"] = None

    return base


# ── Public service functions ──────────────────────────────────────────────────

def create_recommendation(
    request: RecommendRequest,
    user_id: UUID,
    db: Session,
) -> Recommendation:
    """
    Validate file ownership, run the stub prediction pipeline, persist the result.
    """
    # Validate that the file exists and belongs to the requesting user
    stl_file = db.query(STLFile).filter(STLFile.id == request.file_id).first()
    if stl_file is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="STL file not found",
        )
    if str(stl_file.user_id) != str(user_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to access this file",
        )

    prediction = _stub_predict(request)

    rec = Recommendation(
        user_id=user_id,
        stl_file_id=request.file_id,
        orientation_rank=request.orientation_rank,
        intended_use=request.intended_use,
        surface_finish=request.surface_finish,
        needs_flexibility=request.needs_flexibility,
        strength_required=request.strength_required,
        budget_priority=request.budget_priority,
        outdoor_use=request.outdoor_use,
        priority_face=request.priority_face,
        technology=prediction["technology"],
        material=prediction["material"],
        technology_confidence=prediction["technology_confidence"],
        material_confidence=prediction["material_confidence"],
        confidence_tier=prediction["confidence_tier"],
        layer_height=prediction["layer_height"],
        layer_height_min=prediction.get("layer_height_min"),
        layer_height_max=prediction.get("layer_height_max"),
        infill_density=prediction["infill_density"],
        print_speed=prediction["print_speed"],
        wall_count=prediction["wall_count"],
        cooling_fan=prediction["cooling_fan"],
        support_density=prediction["support_density"],
        cost_score=prediction["cost_score"],
        quality_score=prediction["quality_score"],
        speed_score=prediction["speed_score"],
        needs_clarification=prediction["needs_clarification"],
        clarification_question=prediction.get("clarification_question"),
        clarification_field=prediction.get("clarification_field"),
        alternative_json=prediction.get("alternative"),
    )

    db.add(rec)
    db.commit()
    db.refresh(rec)
    logger.info("Recommendation %s created for file %s", rec.id, request.file_id)
    return rec


def rate_recommendation(
    recommendation_id: UUID,
    rating: int,
    user_id: UUID,
    db: Session,
) -> Recommendation:
    rec = db.query(Recommendation).filter(
        Recommendation.id == recommendation_id,
        Recommendation.user_id == user_id,
    ).first()
    if rec is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Recommendation not found",
        )
    rec.user_rating = rating
    db.commit()
    db.refresh(rec)
    return rec


def get_history(user_id: UUID, db: Session) -> list[Recommendation]:
    return (
        db.query(Recommendation)
        .filter(Recommendation.user_id == user_id)
        .order_by(Recommendation.created_at.desc())
        .all()
    )
