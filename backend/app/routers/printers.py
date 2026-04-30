from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import Response
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import require_role
from app.schemas.printer import (
    PrinterCreate,
    PrinterRead,
    PrinterStatus,
    PrinterStatusValue,
    PrinterTestResult,
    PrinterUpdate,
    Technology,
)
from app.services import printer_service

router = APIRouter(prefix="/printers", tags=["Printers"])


@router.get(
    "/",
    response_model=list[PrinterRead],
    status_code=status.HTTP_200_OK,
    summary="List printers with optional filters",
)
def list_printers(
    technology: Technology | None = Query(None),
    status_value: PrinterStatusValue | None = Query(None, alias="status"),
    db: Session = Depends(get_db),
):
    return printer_service.list_printers(
        db=db,
        technology=technology,
        status_value=status_value,
    )


@router.get(
    "/{printer_id}",
    response_model=PrinterRead,
    status_code=status.HTTP_200_OK,
    summary="Get printer by id",
)
def get_printer(printer_id: UUID, db: Session = Depends(get_db)):
    printer = printer_service.get_printer(db, printer_id)
    if printer is None:
        raise HTTPException(status_code=404, detail="Printer not found")
    return printer


@router.post(
    "/",
    response_model=PrinterRead,
    status_code=status.HTTP_201_CREATED,
    summary="Create a printer (admin only)",
)
def create_printer(
    payload: PrinterCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_role("admin")),
):
    return printer_service.create_printer(db, payload)


@router.put(
    "/{printer_id}",
    response_model=PrinterRead,
    status_code=status.HTTP_200_OK,
    summary="Update a printer (admin only)",
)
def update_printer(
    printer_id: UUID,
    payload: PrinterUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_role("admin")),
):
    return printer_service.update_printer(db, printer_id, payload)


@router.delete(
    "/{printer_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a printer (admin only)",
)
def delete_printer(
    printer_id: UUID,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_role("admin")),
):
    printer_service.delete_printer(db, printer_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get(
    "/{printer_id}/status",
    response_model=PrinterStatus,
    status_code=status.HTTP_200_OK,
    summary="Get printer status (stub)",
)
def get_printer_status(printer_id: UUID, db: Session = Depends(get_db)):
    printer = printer_service.get_printer(db, printer_id)
    if printer is None:
        raise HTTPException(status_code=404, detail="Printer not found")
    return PrinterStatus(
        printer_id=printer.id,
        status=printer.status,
        current_job_id=None,
        progress_pct=None,
        temperature_nozzle=None,
        temperature_bed=None,
        last_seen_at=printer.last_seen_at,
    )


@router.post(
    "/{printer_id}/test",
    response_model=PrinterTestResult,
    status_code=status.HTTP_200_OK,
    summary="Test printer connection (stub, admin only)",
)
def test_printer_connection(
    printer_id: UUID,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_role("admin")),
):
    printer = printer_service.get_printer(db, printer_id)
    if printer is None:
        raise HTTPException(status_code=404, detail="Printer not found")
    return PrinterTestResult(
        printer_id=printer.id,
        ok=True,
        message="Mock OK",
    )
