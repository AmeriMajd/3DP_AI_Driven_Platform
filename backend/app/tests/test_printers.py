import uuid

from fastapi import status

from app.core.security import hash_password
from app.models.printer import Printer
from app.models.user import User


def _create_operator(db_session) -> User:
    user = User(
        id=uuid.uuid4(),
        email="operator@test.com",
        full_name="Operator User",
        password=hash_password("password456"),
        role="operator",
        is_active=True,
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


def test_list_printers_returns_seeded(client, db_session):
    printer = Printer(
        id=uuid.uuid4(),
        name="Prusa MK4 #1",
        model="MK4",
        technology="FDM",
        connector_type="mock",
        status="idle",
        materials_supported=["PLA", "PETG"],
    )
    db_session.add(printer)
    db_session.commit()

    resp = client.get("/printers")
    assert resp.status_code == status.HTTP_200_OK
    data = resp.json()
    assert any(item["id"] == str(printer.id) for item in data)


def test_create_printer_admin_succeeds(client, test_user_token):
    payload = {
        "name": "Bambu X1C #1",
        "technology": "FDM",
        "connector_type": "mock",
        "status": "idle",
    }
    resp = client.post(
        "/printers",
        json=payload,
        headers={"Authorization": f"Bearer {test_user_token}"},
    )
    assert resp.status_code == status.HTTP_201_CREATED
    data = resp.json()
    assert data["name"] == payload["name"]
    assert "api_key" not in data
    assert "api_key_encrypted" not in data


def test_create_printer_non_admin_forbidden(client, db_session):
    operator = _create_operator(db_session)
    token = client.post(
        "/auth/login",
        json={"email": operator.email, "password": "password456"},
    ).json()["access_token"]

    resp = client.post(
        "/printers",
        json={"name": "Formlabs Form 3", "technology": "SLA"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == status.HTTP_403_FORBIDDEN


def test_get_printer_status_shape(client, db_session):
    printer = Printer(
        id=uuid.uuid4(),
        name="OctoPrint Demo",
        technology="FDM",
        connector_type="octoprint",
        status="offline",
    )
    db_session.add(printer)
    db_session.commit()

    resp = client.get(f"/printers/{printer.id}/status")
    assert resp.status_code == status.HTTP_200_OK
    data = resp.json()
    assert data["printer_id"] == str(printer.id)
    assert data["status"] == "offline"
    assert "current_job_id" in data
    assert "progress_pct" in data
    assert "temperature_nozzle" in data
    assert "temperature_bed" in data
    assert "last_seen_at" in data


def test_api_key_never_in_response(client, test_user_token):
    payload = {
        "name": "Prusa MK4 #2",
        "technology": "FDM",
        "connector_type": "mock",
        "api_key": "super-secret",
    }
    create_resp = client.post(
        "/printers",
        json=payload,
        headers={"Authorization": f"Bearer {test_user_token}"},
    )
    assert create_resp.status_code == status.HTTP_201_CREATED
    created = create_resp.json()
    assert "api_key" not in created
    assert "api_key_encrypted" not in created

    list_resp = client.get("/printers")
    assert list_resp.status_code == status.HTTP_200_OK
    for item in list_resp.json():
        assert "api_key" not in item
        assert "api_key_encrypted" not in item


def test_update_and_delete_flow(client, test_user_token):
    create_resp = client.post(
        "/printers",
        json={"name": "Temp Printer", "technology": "FDM"},
        headers={"Authorization": f"Bearer {test_user_token}"},
    )
    printer_id = create_resp.json()["id"]

    update_resp = client.put(
        f"/printers/{printer_id}",
        json={"name": "Updated Printer", "status": "maintenance"},
        headers={"Authorization": f"Bearer {test_user_token}"},
    )
    assert update_resp.status_code == status.HTTP_200_OK
    assert update_resp.json()["name"] == "Updated Printer"
    assert update_resp.json()["status"] == "maintenance"

    delete_resp = client.delete(
        f"/printers/{printer_id}",
        headers={"Authorization": f"Bearer {test_user_token}"},
    )
    assert delete_resp.status_code == status.HTTP_204_NO_CONTENT

    get_resp = client.get(f"/printers/{printer_id}")
    assert get_resp.status_code == status.HTTP_404_NOT_FOUND
