from typing import TYPE_CHECKING

from app.connectors.base import BaseConnector
from app.connectors.mock import MockConnector
from app.connectors.octoprint import OctoPrintConnector
from app.connectors.prusalink import PrusaLinkConnector

if TYPE_CHECKING:
    from app.models.printer import Printer


def get_connector(printer: "Printer", decrypted_api_key: str | None = None) -> BaseConnector:
    """Return the correct connector for *printer*.

    Pass *decrypted_api_key* (from printer_service.get_decrypted_api_key) so
    the connector receives the plaintext key without re-decrypting.
    """

    class _P:
        """Thin proxy that injects the decrypted key."""
        def __init__(self, p, key):
            self._p = p
            self.api_key = key

        def __getattr__(self, name):
            return getattr(self._p, name)

    p = _P(printer, decrypted_api_key)

    match printer.connector_type:
        case "octoprint":
            return OctoPrintConnector(p)
        case "prusalink":
            return PrusaLinkConnector(p)
        case "mock" | "manual":
            return MockConnector(p)
        case _:
            raise ValueError(f"Unknown connector type: {printer.connector_type}")
