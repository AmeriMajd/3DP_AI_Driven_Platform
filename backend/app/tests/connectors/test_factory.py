"""
Unit tests for connector factory.
Verifies dispatch logic — no HTTP calls.
"""

import uuid
from types import SimpleNamespace

import httpx
import pytest

from app.connectors.factory import get_connector
from app.connectors.mock import MockConnector
from app.connectors.octoprint import OctoPrintConnector
from app.connectors.prusalink import PrusaLinkConnector


def _printer(connector_type, url="http://printer.local", api_key="k", username="u"):
    return SimpleNamespace(
        id=uuid.uuid4(),
        connector_type=connector_type,
        connection_url=url,
        api_key=api_key,
        username=username,
    )


def test_mock_connector():
    assert isinstance(get_connector(_printer("mock")), MockConnector)


def test_manual_routes_to_mock():
    assert isinstance(get_connector(_printer("manual")), MockConnector)


def test_octoprint_connector():
    assert isinstance(get_connector(_printer("octoprint")), OctoPrintConnector)


def test_prusalink_connector():
    assert isinstance(get_connector(_printer("prusalink")), PrusaLinkConnector)


def test_unknown_type_raises():
    with pytest.raises(ValueError, match="Unknown connector type"):
        get_connector(_printer("foobar"))


def test_empty_type_raises():
    with pytest.raises(ValueError, match="Unknown connector type"):
        get_connector(_printer(""))


def test_decrypted_api_key_injected_into_octoprint():
    p = _printer("octoprint")
    c = get_connector(p, decrypted_api_key="plaintext-key")
    assert isinstance(c, OctoPrintConnector)
    assert c._headers["X-Api-Key"] == "plaintext-key"


def test_decrypted_api_key_none_uses_empty_string():
    p = _printer("octoprint", api_key=None)
    c = get_connector(p, decrypted_api_key=None)
    assert c._headers["X-Api-Key"] == ""


def test_prusalink_uses_digest_auth():
    p = _printer("prusalink", username="myuser", api_key="mypass")
    c = get_connector(p)
    assert isinstance(c, PrusaLinkConnector)
    assert isinstance(c._auth, httpx.DigestAuth)
