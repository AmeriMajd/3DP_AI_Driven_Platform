"""
Tests for GET /recommend/{id}/export?slicer=cura|prusaslicer.

Covers:
  - Cura export returns 200 with correct Content-Disposition
  - Cura export produces a parseable .inst.cfg with the right sections/keys
  - PrusaSlicer export returns 200 with correct Content-Disposition
  - PrusaSlicer export contains expected INI keys
  - 404 when recommendation does not belong to the requesting user
  - 422 when the slicer query param is invalid
  - 401 when no auth token is provided

Setup note:
  STLFile and Recommendation are inserted directly via the db_session fixture
  to bypass the recommendation service and avoid a UUID/SQLite dialect mismatch
  that only manifests with the PostgreSQL UUID column type on an in-memory SQLite
  engine (the production code works correctly with PostgreSQL).
"""

import configparser
import uuid
import pytest
from fastapi import status

from app.models.recommendation import Recommendation
from app.models.stl_file import STLFile


# ── Fixtures ──────────────────────────────────────────────────────────────────

@pytest.fixture
def seeded_recommendation(db_session, test_user):
    """Insert an STLFile + Recommendation directly, bypassing the service."""
    stl = STLFile(
        id=uuid.uuid4(),
        user_id=test_user.id,
        original_filename="cube.stl",
        stored_filename=f"cube_{uuid.uuid4().hex}.stl",
        file_size_bytes=1024,
    )
    db_session.add(stl)
    db_session.flush()

    rec = Recommendation(
        id=uuid.uuid4(),
        user_id=test_user.id,
        stl_file_id=stl.id,
        intended_use="decorative",
        surface_finish="standard",
        needs_flexibility=False,
        strength_required="low",
        budget_priority="cost",
        outdoor_use=False,
        technology="FDM",
        material="PLA",
        technology_confidence=0.90,
        material_confidence=0.88,
        confidence_tier="high",
        layer_height=0.20,
        layer_height_min=0.10,
        layer_height_max=0.30,
        infill_density=20,
        print_speed=50,
        wall_count=3,
        cooling_fan=80,
        support_density=0,
        cost_score=80,
        quality_score=75,
        speed_score=70,
        needs_clarification=False,
    )
    db_session.add(rec)
    db_session.commit()
    return rec


# ── Cura export ───────────────────────────────────────────────────────────────

def test_export_cura_returns_200(client, test_user_token, seeded_recommendation):
    resp = client.get(
        f"/recommend/{seeded_recommendation.id}/export?slicer=cura",
        headers={"Authorization": f"Bearer {test_user_token}"},
    )
    assert resp.status_code == status.HTTP_200_OK


def test_export_cura_content_disposition(client, test_user_token, seeded_recommendation):
    resp = client.get(
        f"/recommend/{seeded_recommendation.id}/export?slicer=cura",
        headers={"Authorization": f"Bearer {test_user_token}"},
    )
    cd = resp.headers.get("content-disposition", "")
    assert "attachment" in cd
    assert ".inst.cfg" in cd


def test_export_cura_valid_ini_structure(client, test_user_token, seeded_recommendation):
    resp = client.get(
        f"/recommend/{seeded_recommendation.id}/export?slicer=cura",
        headers={"Authorization": f"Bearer {test_user_token}"},
    )
    cfg = configparser.ConfigParser()
    cfg.read_string(resp.text)

    assert cfg.has_section("general")
    assert cfg.has_section("metadata")
    assert cfg.has_section("values")
    assert cfg.get("general", "definition") == "fdmprinter"
    assert cfg.get("metadata", "type") == "quality"


def test_export_cura_contains_print_params(client, test_user_token, seeded_recommendation):
    resp = client.get(
        f"/recommend/{seeded_recommendation.id}/export?slicer=cura",
        headers={"Authorization": f"Bearer {test_user_token}"},
    )
    cfg = configparser.ConfigParser()
    cfg.read_string(resp.text)

    assert cfg.has_option("values", "layer_height")
    assert cfg.has_option("values", "infill_sparse_density")
    assert cfg.has_option("values", "speed_print")
    assert cfg.has_option("values", "wall_line_count")


# ── PrusaSlicer export ────────────────────────────────────────────────────────

def test_export_prusaslicer_returns_200(client, test_user_token, seeded_recommendation):
    resp = client.get(
        f"/recommend/{seeded_recommendation.id}/export?slicer=prusaslicer",
        headers={"Authorization": f"Bearer {test_user_token}"},
    )
    assert resp.status_code == status.HTTP_200_OK


def test_export_prusaslicer_content_disposition(client, test_user_token, seeded_recommendation):
    resp = client.get(
        f"/recommend/{seeded_recommendation.id}/export?slicer=prusaslicer",
        headers={"Authorization": f"Bearer {test_user_token}"},
    )
    cd = resp.headers.get("content-disposition", "")
    assert "attachment" in cd
    assert ".ini" in cd


def test_export_prusaslicer_contains_print_params(client, test_user_token, seeded_recommendation):
    resp = client.get(
        f"/recommend/{seeded_recommendation.id}/export?slicer=prusaslicer",
        headers={"Authorization": f"Bearer {test_user_token}"},
    )
    text = resp.text
    assert "layer_height" in text
    assert "fill_density" in text
    assert "perimeters" in text
    assert "perimeter_speed" in text


# ── Error cases ───────────────────────────────────────────────────────────────

def test_export_404_unknown_recommendation(client, test_user_token):
    resp = client.get(
        f"/recommend/{uuid.uuid4()}/export?slicer=cura",
        headers={"Authorization": f"Bearer {test_user_token}"},
    )
    assert resp.status_code == status.HTTP_404_NOT_FOUND


def test_export_422_invalid_slicer(client, test_user_token, seeded_recommendation):
    resp = client.get(
        f"/recommend/{seeded_recommendation.id}/export?slicer=ideamaker",
        headers={"Authorization": f"Bearer {test_user_token}"},
    )
    assert resp.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY


def test_export_401_without_token(client, seeded_recommendation):
    resp = client.get(f"/recommend/{seeded_recommendation.id}/export?slicer=cura")
    assert resp.status_code == status.HTTP_401_UNAUTHORIZED
