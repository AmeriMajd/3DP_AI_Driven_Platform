from __future__ import annotations
from dataclasses import dataclass


@dataclass
class Estimation:
    """Estimation snapshot extracted from a Recommendation row.

    Not an ORM model — estimation columns live on the recommendations table.
    Use from_recommendation() to build this from an ORM object.
    """
    recommendation_id: str
    estimated_cost: float | None
    estimated_time_minutes: int | None
    currency: str
    pricing_version: str
    estimation_confidence: str  # "high" | "low"

    @classmethod
    def from_recommendation(cls, rec: object) -> "Estimation":
        return cls(
            recommendation_id=str(rec.id),
            estimated_cost=rec.estimated_cost,
            estimated_time_minutes=rec.estimated_time_minutes,
            currency=rec.currency or "TND",
            pricing_version=rec.pricing_version or "",
            estimation_confidence=rec.estimation_confidence or "low",
        )
