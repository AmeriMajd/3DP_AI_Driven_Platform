from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.crypto import decrypt_api_key, encrypt_api_key
from app.models.printer import Printer
from app.schemas.printer import PrinterCreate, PrinterUpdate


def list_printers(
    db: Session,
    technology: str | None = None,
    status_value: str | None = None,
) -> list[Printer]:
    query = db.query(Printer)
    if technology is not None:
        query = query.filter(Printer.technology == technology)
    if status_value is not None:
        query = query.filter(Printer.status == status_value)
    return query.order_by(Printer.created_at.desc()).all()


def get_printer(db: Session, printer_id: UUID) -> Printer | None:
    return db.query(Printer).filter(Printer.id == printer_id).first()


def create_printer(db: Session, payload: PrinterCreate) -> Printer:
    data = payload.model_dump(exclude={"api_key"})
    printer = Printer(**data)

    if payload.api_key is not None:
        printer.api_key_encrypted = encrypt_api_key(payload.api_key)

    db.add(printer)
    db.commit()
    db.refresh(printer)
    return printer


def update_printer(db: Session, printer_id: UUID, payload: PrinterUpdate) -> Printer:
    printer = get_printer(db, printer_id)
    if printer is None:
        raise HTTPException(status_code=404, detail="Printer not found")

    updates = payload.model_dump(exclude_unset=True)
    api_key_provided = "api_key" in updates
    api_key_value = updates.pop("api_key", None)

    for field, value in updates.items():
        setattr(printer, field, value)

    if api_key_provided:
        printer.api_key_encrypted = (
            None if api_key_value is None else encrypt_api_key(api_key_value)
        )

    db.commit()
    db.refresh(printer)
    return printer


def delete_printer(db: Session, printer_id: UUID) -> None:
    printer = get_printer(db, printer_id)
    if printer is None:
        raise HTTPException(status_code=404, detail="Printer not found")

    db.delete(printer)
    db.commit()


def get_decrypted_api_key(printer: Printer) -> str | None:
    if not printer.api_key_encrypted:
        return None
    return decrypt_api_key(printer.api_key_encrypted)
