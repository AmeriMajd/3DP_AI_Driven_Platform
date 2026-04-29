import os
import sys
from pathlib import Path

from sqlalchemy.orm import Session

BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.core.database import Base, SessionLocal, engine
import app.models.printer
from app.models.printer import Printer


def seed_printers(db: Session) -> int:
    octoprint_url = os.getenv("OCTOPRINT_URL") or None

    seed_data = [
        {
            "name": "Prusa MK4 #1",
            "technology": "FDM",
            "connector_type": "mock",
            "status": "idle",
            "materials_supported": ["PLA", "PETG", "ABS"],
        },
        {
            "name": "Bambu X1C #1",
            "technology": "FDM",
            "connector_type": "mock",
            "status": "idle",
            "materials_supported": ["PLA", "PETG", "TPU"],
        },
        {
            "name": "Formlabs Form 3",
            "technology": "SLA",
            "connector_type": "mock",
            "status": "idle",
            "materials_supported": ["Standard Resin", "Tough"],
        },
        {
            "name": "OctoPrint Demo",
            "technology": "FDM",
            "connector_type": "octoprint",
            "connection_url": octoprint_url,
            "status": "offline",
        },
    ]

    created = 0
    for data in seed_data:
        existing = db.query(Printer).filter(Printer.name == data["name"]).first()
        if existing:
            continue
        db.add(Printer(**data))
        created += 1

    if created:
        db.commit()

    return created


def main() -> None:
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        created = seed_printers(db)
        total = db.query(Printer).count()
        print(f"Seeded {created} printers. Total printers: {total}")
    finally:
        db.close()


if __name__ == "__main__":
    main()
