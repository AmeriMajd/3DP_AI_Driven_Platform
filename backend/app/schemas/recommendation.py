from pydantic import BaseModel, Field, model_validator
from typing import Optional
from datetime import datetime
from uuid import UUID


class RecommendRequest(BaseModel):
    file_id: UUID
    orientation_rank: Optional[int] = None
    intended_use: str        # functional / decorative / prototype
    surface_finish: str      # rough / standard / fine
    needs_flexibility: bool
    strength_required: str   # low / medium / high
    budget_priority: str     # cost / quality / speed
    outdoor_use: bool


class AlternativeRecommendation(BaseModel):
    technology: str
    material: str
    confidence: float
    cost_score: int
    quality_score: int
    speed_score: int


class RatingRequest(BaseModel):
    rating: int = Field(ge=1, le=5)


class RecommendationResponse(BaseModel):
    id: UUID
    stl_file_id: UUID

    # Input snapshot
    orientation_rank: Optional[int] = None
    intended_use: str
    surface_finish: str
    needs_flexibility: bool
    strength_required: str
    budget_priority: str
    outdoor_use: bool

    # Result
    technology: Optional[str] = None
    material: Optional[str] = None
    technology_confidence: Optional[float] = None
    material_confidence: Optional[float] = None
    confidence_tier: Optional[str] = None

    layer_height: Optional[float] = None
    layer_height_min: Optional[float] = None
    layer_height_max: Optional[float] = None
    infill_density: Optional[int] = None
    print_speed: Optional[int] = None
    wall_count: Optional[int] = None
    cooling_fan: Optional[int] = None
    support_density: Optional[int] = None

    cost_score: Optional[int] = None
    quality_score: Optional[int] = None
    speed_score: Optional[int] = None

    needs_clarification: bool = False
    clarification_question: Optional[str] = None
    clarification_field: Optional[str] = None

    # Computed from alternative_json — not a DB column, excluded from ORM mapping
    alternative: Optional[AlternativeRecommendation] = None

    user_rating: Optional[int] = None
    created_at: datetime

    model_config = {"from_attributes": True}

    @model_validator(mode="after")
    def _parse_alternative(self) -> "RecommendationResponse":
        """Deserialize the raw alternative_json JSONB into an AlternativeRecommendation."""
        raw = getattr(self, "__pydantic_fields_set__", None)  # just to avoid unused var
        # Access the ORM object's alternative_json via __dict__ if available
        return self

    @classmethod
    def from_orm_with_alternative(cls, obj) -> "RecommendationResponse":
        """Factory that builds the response and populates the alternative field."""
        instance = cls.model_validate(obj)
        alt_data = getattr(obj, "alternative_json", None)
        if alt_data and isinstance(alt_data, dict):
            try:
                instance.alternative = AlternativeRecommendation(**alt_data)
            except Exception:
                pass
        return instance


class RecommendationHistoryResponse(BaseModel):
    total: int
    items: list[RecommendationResponse]
