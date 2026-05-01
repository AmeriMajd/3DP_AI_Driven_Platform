"""
Seed 4 demo printers.

Run with:
    python -m app.scripts.seed_printers

Idempotent: skips printers whose name already exists.

Materials use the canonical vocabulary from the recommender:
    FDM: PLA, ABS, PETG, TPU
    SLA: Resin-Std, Resin-Eng
"""

import os

from app.core.database import SessionLocal
from app.models.printer import Printer


SEED_PRINTERS = [
    {
        "name": "Prusa MK4 #1",
        "model": "Original Prusa MK4",
        "technology": "FDM",
        "build_volume_x": 250.0,
        "build_volume_y": 210.0,
        "build_volume_z": 220.0,
        "connector_type": "mock",
        "status": "idle",
        "materials_supported": ["PLA", "PETG", "ABS"],
    },
    {
        "name": "Bambu X1C #1",
        "model": "Bambu Lab X1 Carbon",
        "technology": "FDM",
        "build_volume_x": 256.0,
        "build_volume_y": 256.0,
        "build_volume_z": 256.0,
        "connector_type": "mock",
        "status": "idle",
        "materials_supported": ["PLA", "PETG", "TPU"],
    },
    {
        "name": "Formlabs Form 3",
        "model": "Form 3",
        "technology": "SLA",
        "build_volume_x": 145.0,
        "build_volume_y": 145.0,
        "build_volume_z": 185.0,
        "connector_type": "mock",
        "status": "idle",
        "materials_supported": ["Resin-Std", "Resin-Eng"],
    },
    {
        "name": "OctoPrint Demo",
        "model": "Generic FDM via OctoPrint",
        "technology": "FDM",
        "build_volume_x": 220.0,
        "build_volume_y": 220.0,
        "build_volume_z": 250.0,
        "connector_type": "octoprint",
        "connection_url": os.environ.get("OCTOPRINT_DEMO_URL"),
        "status": "offline",
        "materials_supported": ["PLA", "PETG"],
    },
]


def seed() -> None:
    db = SessionLocal()
    try:
        created = 0
        skipped = 0
        for spec in SEED_PRINTERS:
            existing = db.query(Printer).filter(Printer.name == spec["name"]).first()
            if existing is not None:
                skipped += 1
                continue
            printer = Printer(**spec)
            db.add(printer)
            created += 1
        db.commit()
        print(f"Seed complete. Created: {created}, skipped (already exist): {skipped}")
    finally:
        db.close()


if __name__ == "__main__":
    seed()