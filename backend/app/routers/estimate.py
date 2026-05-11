"""
POST /estimate — compute & persist cost/time estimates for a recommendation.

Estimation is deliberately decoupled from the recommendation creation flow:
the client calls this endpoint after a recommendation exists. Re-calling is
idempotent — values are recomputed and overwritten.
"""
import logging

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.recommendation import Recommendation
from app.models.stl_file import STLFile
from app.schemas.recommendation import (
    EstimateRequest,
    EstimateResponse,
    EstimateValues,
)
from app.services import estimation_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/estimate", tags=["Estimation"])


def _geo_dict(stl_file: STLFile) -> dict:
    return {
        "volume_cm3":       stl_file.volume_cm3,
        "surface_area_cm2": stl_file.surface_area_cm2,
        "bbox_x_mm":        stl_file.bbox_x_mm,
        "bbox_y_mm":        stl_file.bbox_y_mm,
        "bbox_z_mm":        stl_file.bbox_z_mm,
    }


def _primary_params(rec: Recommendation) -> dict:
    return {
        "technology":     rec.technology,
        "material":       rec.material,
        "layer_height":   rec.layer_height,
        "infill_density": rec.infill_density,
        "print_speed":    rec.print_speed,
        "wall_count":     rec.wall_count,
    }


@router.post(
    "",
    response_model=EstimateResponse,
    summary="Compute & persist cost/time estimate for a recommendation",
)
def post_estimate(
    body: EstimateRequest,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> EstimateResponse:
    rec = db.query(Recommendation).filter(
        Recommendation.id == body.recommendation_id,
        Recommendation.user_id == current_user["user_id"],
    ).first()
    if rec is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Recommendation not found",
        )

    stl_file = db.query(STLFile).filter(STLFile.id == rec.stl_file_id).first()
    if stl_file is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="STL file not found for this recommendation",
        )

    geo = _geo_dict(stl_file)
    selected_orientation = rec.selected_orientation_json

    # Primary
    primary_est = estimation_service.estimate(
        geo, _primary_params(rec), selected_orientation,
    ).to_dict()

    rec.estimated_cost = primary_est.get("estimated_cost")
    rec.estimated_time_minutes = primary_est.get("estimated_time_minutes")
    rec.currency = primary_est.get("currency")
    rec.pricing_version = primary_est.get("pricing_version")
    rec.estimation_confidence = primary_est.get("estimation_confidence")

    # Alternative (if any) — merge into the JSON blob
    alt_values: EstimateValues | None = None
    alt_blob = rec.alternative_json
    if isinstance(alt_blob, dict):
        alt_est = estimation_service.estimate(
            geo, alt_blob, selected_orientation,
        ).to_dict()
        merged = dict(alt_blob)
        merged.update(alt_est)
        rec.alternative_json = merged
        # SQLAlchemy JSON columns need an explicit flag for in-place mutation
        # safety; reassigning above is enough, but mark dirty just in case.
        from sqlalchemy.orm.attributes import flag_modified
        flag_modified(rec, "alternative_json")
        alt_values = EstimateValues(**alt_est)

    db.commit()
    db.refresh(rec)

    logger.info("estimate computed for recommendation %s", rec.id)
    return EstimateResponse(
        recommendation_id=rec.id,
        primary=EstimateValues(**primary_est),
        alternative=alt_values,
    )
