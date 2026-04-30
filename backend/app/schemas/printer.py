"""
Pydantic v2 schemas for Printer.

Note: PrinterRead intentionally omits `api_key_encrypted`. Never add it.
A test in tests/test_printers.py asserts this invariant.
"""

from datetime import datetime
from typing import Literal, Optional
from uuid import UUID

from pydantic import BaseModel, Field

# Reusable enum-like Literal types
Technology = Literal["FDM", "SLA"]
ConnectorType = Literal["octoprint", "prusalink", "mock", "manual"]
PrinterStatusValue = Literal["idle", "printing", "error", "offline", "maintenance"]


# ---------- Base / Create / Update ----------


class PrinterBase(BaseModel):
    """Fields shared between create and update payloads."""

    name: str
    model: Optional[str] = None
    technology: Technology
    build_volume_x: Optional[float] = None
    build_volume_y: Optional[float] = None
    build_volume_z: Optional[float] = None
    connector_type: ConnectorType = "mock"
    connection_url: Optional[str] = None
    materials_supported: Optional[list[str]] = None


class PrinterCreate(PrinterBase):
    # Plaintext API key — encrypted by the service before persisting.
    api_key: Optional[str] = Field(default=None, repr=False)
    status: PrinterStatusValue = "offline"


class PrinterUpdate(BaseModel):
    """All fields optional — partial update."""

    name: Optional[str] = None
    model: Optional[str] = None
    technology: Optional[Technology] = None
    build_volume_x: Optional[float] = None
    build_volume_y: Optional[float] = None
    build_volume_z: Optional[float] = None
    connector_type: Optional[ConnectorType] = None
    connection_url: Optional[str] = None
    materials_supported: Optional[list[str]] = None
    status: Optional[PrinterStatusValue] = None
    # Plaintext — re-encrypted by the service if provided
    api_key: Optional[str] = Field(default=None, repr=False)


# ---------- Read (response model) ----------


class PrinterRead(BaseModel):
    """Public response shape. NEVER includes api_key_encrypted."""

    id: UUID
    name: str
    model: Optional[str] = None
    technology: Technology
    build_volume_x: Optional[float] = None
    build_volume_y: Optional[float] = None
    build_volume_z: Optional[float] = None
    connector_type: ConnectorType
    status: PrinterStatusValue
    materials_supported: Optional[list[str]] = None
    last_seen_at: Optional[datetime] = None
    created_at: datetime

    model_config = {"from_attributes": True}


# ---------- Status endpoint ----------


class PrinterStatus(BaseModel):
    """Shape returned by GET /printers/{id}/status."""

    printer_id: UUID
    status: PrinterStatusValue
    current_job_id: Optional[UUID] = None
    progress_pct: Optional[float] = None
    temperature_nozzle: Optional[float] = None
    temperature_bed: Optional[float] = None
    last_seen_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


# ---------- Test-connection endpoint ----------


class PrinterTestResult(BaseModel):
    """Shape returned by POST /printers/{id}/test."""

    printer_id: UUID
    ok: bool
    message: str