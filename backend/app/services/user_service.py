from uuid import UUID

from fastapi import HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.print_job import PrintJob
from app.models.recommendation import Recommendation
from app.models.refresh_token import RefreshToken
from app.models.stl_file import STLFile
from app.models.user import User
from app.schemas.auth import UpdateProfileSchema, UserMeResponse, UserStats


class UserService:
    def __init__(self, db: Session):
        self.db = db

    def get_user_or_404(self, user_id: str | UUID) -> User:
        user = self.db.query(User).filter(User.id == self._parse_user_id(user_id)).first()
        if user is None:
            raise HTTPException(status_code=404, detail="User not found")
        return user

    def ensure_email_available(
        self,
        email: str,
        exclude_user_id: str | UUID | None = None,
    ) -> None:
        query = self.db.query(User).filter(User.email == email)
        if exclude_user_id is not None:
            query = query.filter(User.id != self._parse_user_id(exclude_user_id))

        if query.first() is not None:
            raise HTTPException(status_code=400, detail="Email already in use")

    def update_profile(self, user_id: str | UUID, data: UpdateProfileSchema) -> User:
        user = self.get_user_or_404(user_id)

        if data.full_name:
            user.full_name = data.full_name
        if data.email:
            self.ensure_email_available(data.email, exclude_user_id=user.id)
            user.email = data.email

        self.db.commit()
        self.db.refresh(user)
        return user

    def get_user_me(self, user_id: str | UUID) -> UserMeResponse:
        user = self.get_user_or_404(user_id)
        last_token = (
            self.db.query(RefreshToken)
            .filter(RefreshToken.user_id == user.id)
            .order_by(RefreshToken.created_at.desc())
            .first()
        )

        return UserMeResponse(
            id=user.id,
            email=user.email,
            full_name=user.full_name,
            role=user.role,
            created_at=user.created_at,
            last_login=last_token.created_at if last_token else None,
            stats=self.get_user_stats(user.id),
        )

    def get_user_stats(self, user_id: str | UUID) -> UserStats:
        user_uuid = self._parse_user_id(user_id)
        files_count = (
            self.db.query(func.count())
            .select_from(STLFile)
            .filter(STLFile.user_id == user_uuid)
            .scalar()
        )
        recs_count = (
            self.db.query(func.count())
            .select_from(Recommendation)
            .filter(Recommendation.user_id == user_uuid)
            .scalar()
        )
        jobs_count = (
            self.db.query(func.count())
            .select_from(PrintJob)
            .filter(PrintJob.user_id == user_uuid)
            .scalar()
        )

        return UserStats(
            files_uploaded=files_count or 0,
            recommendations_count=recs_count or 0,
            jobs_submitted=jobs_count or 0,
        )

    def _parse_user_id(self, user_id: str | UUID) -> UUID:
        if isinstance(user_id, UUID):
            return user_id
        return UUID(str(user_id))
