from app.core.database import SessionLocal
# Register all model tables with Base.metadata so FKs resolve.
import app.models.user  # noqa: F401
import app.models.notification  # noqa: F401
import app.models.user_device  # noqa: F401
from app.services import notification_service
from uuid import UUID

USER_ID = UUID("f2dbc478-c6fa-4b9c-b680-fad9704b41e1")

db = SessionLocal()
n = notification_service.emit(
      db,
      user_id=USER_ID,
      category="print_job",
      type_="print.failed",
      title="Test push",
      body="If you see this, FCM works",
      severity="error",
      data={"job_id": "00000000-0000-0000-0000-000000000000"},
  )
db.commit()
print(f"emitted notification id={n.id if n else 'DROPPED'}")