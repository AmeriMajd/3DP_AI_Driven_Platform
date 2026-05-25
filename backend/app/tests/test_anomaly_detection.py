"""Tests for anomaly detection rules (US-21).

Covers the 3 polling-driven rules. Rule 4 (unreachable) is exercised by the
existing watchdog and is not duplicated here.
"""

import uuid
from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock

import pytest

from app.connectors.base import PrinterState, PrinterStatus
from app.models.activity_log import ActivityLog
from app.models.print_job import PrintJob
from app.models.user import User
from app.core.config import settings
from app.core.security import hash_password
from app.services import notification_triggers, status_poll_service


@pytest.fixture(autouse=True)
def _stub_notification(monkeypatch):
    """Bypass notification persistence — Notification.delivered_channels uses
    ARRAY which SQLite can't bind. Anomaly path's notification fan-out is
    covered by unit tests on notification_service elsewhere; here we just
    need ActivityLog + WS assertions to run."""
    monkeypatch.setattr(
        notification_triggers, "emit_job_anomaly", lambda *a, **k: None
    )


@pytest.fixture
def printing_job(db_session):
    user = User(
        id=uuid.uuid4(),
        email="anom@test.com",
        full_name="Anom",
        password=hash_password("password123"),
        role="operator",
        is_active=True,
    )
    db_session.add(user)
    db_session.commit()
    job = PrintJob(
        id=uuid.uuid4(),
        user_id=user.id,
        status="printing",
        progress_pct=50.0,
        started_at=datetime.now(timezone.utc) - timedelta(hours=1),
        estimated_duration_s=1800,  # 30 min — so 1h elapsed = overrun
        progress_updated_at=datetime.now(timezone.utc) - timedelta(minutes=30),
    )
    db_session.add(job)
    db_session.commit()
    return job


def _status(nozzle_actual=200, nozzle_target=200, bed_actual=60, bed_target=60):
    return PrinterStatus(
        state=PrinterState.PRINTING,
        nozzle_temp_actual=nozzle_actual,
        nozzle_temp_target=nozzle_target,
        bed_temp_actual=bed_actual,
        bed_temp_target=bed_target,
        progress=0.5,
        time_left_seconds=600,
        current_job_name=None,
    )


def _count_anomalies(db, anomaly_type=None):
    q = db.query(ActivityLog).filter(ActivityLog.event_type == "anomaly")
    rows = q.all()
    if anomaly_type:
        rows = [r for r in rows if (r.metadata_json or {}).get("anomaly_type") == anomaly_type]
    return len(rows)


def test_thermal_drift_fires_only_after_threshold_polls(db_session, printing_job, monkeypatch):
    status_poll_service._drift_streak.clear()
    monkeypatch.setattr(settings, "ANOMALY_TEMP_DRIFT_POLLS", 3)
    monkeypatch.setattr(settings, "ANOMALY_TEMP_DRIFT_C", 15.0)

    drifted = _status(nozzle_actual=240, nozzle_target=200)
    # First 2 polls — no alert
    status_poll_service._check_anomalies(db_session, printing_job, drifted)
    status_poll_service._check_anomalies(db_session, printing_job, drifted)
    db_session.commit()
    assert _count_anomalies(db_session, "thermal_drift") == 0

    # 3rd poll triggers
    status_poll_service._check_anomalies(db_session, printing_job, drifted)
    db_session.commit()
    assert _count_anomalies(db_session, "thermal_drift") == 1


def test_thermal_drift_resets_on_normal_reading(db_session, printing_job, monkeypatch):
    status_poll_service._drift_streak.clear()
    monkeypatch.setattr(settings, "ANOMALY_TEMP_DRIFT_POLLS", 3)

    drifted = _status(nozzle_actual=240, nozzle_target=200)
    normal = _status()

    status_poll_service._check_anomalies(db_session, printing_job, drifted)
    status_poll_service._check_anomalies(db_session, printing_job, drifted)
    status_poll_service._check_anomalies(db_session, printing_job, normal)
    status_poll_service._check_anomalies(db_session, printing_job, drifted)
    db_session.commit()
    # Streak reset → no alert on 4th
    assert _count_anomalies(db_session, "thermal_drift") == 0


def test_progress_stall_fires(db_session, printing_job, monkeypatch):
    status_poll_service._drift_streak.clear()
    monkeypatch.setattr(settings, "ANOMALY_PROGRESS_STALL_MINUTES", 20)

    printing_job.progress_updated_at = datetime.now(timezone.utc) - timedelta(minutes=25)
    db_session.commit()

    status_poll_service._check_anomalies(db_session, printing_job, _status())
    db_session.commit()
    assert _count_anomalies(db_session, "progress_stall") == 1


def test_progress_stall_does_not_fire_when_recent(db_session, printing_job, monkeypatch):
    status_poll_service._drift_streak.clear()
    monkeypatch.setattr(settings, "ANOMALY_PROGRESS_STALL_MINUTES", 20)

    printing_job.progress_updated_at = datetime.now(timezone.utc) - timedelta(minutes=5)
    db_session.commit()

    status_poll_service._check_anomalies(db_session, printing_job, _status())
    db_session.commit()
    assert _count_anomalies(db_session, "progress_stall") == 0


def test_duration_overrun_fires(db_session, printing_job, monkeypatch):
    status_poll_service._drift_streak.clear()
    monkeypatch.setattr(settings, "ANOMALY_DURATION_OVERRUN_FACTOR", 1.3)

    # started 1h ago, estimated 1800s → elapsed 3600 > 1800 * 1.3 = 2340
    status_poll_service._check_anomalies(db_session, printing_job, _status())
    db_session.commit()
    assert _count_anomalies(db_session, "duration_overrun") == 1


def test_raise_anomaly_writes_activity_log_and_emits_ws(
    db_session, printing_job, monkeypatch
):
    sent = []
    monkeypatch.setattr(
        status_poll_service,
        "emit_job_anomaly",
        lambda job_id, **kw: sent.append((str(job_id), kw)),
    )
    status_poll_service._raise_anomaly(
        db_session,
        printing_job,
        anomaly_type="thermal_drift",
        message="test drift",
        severity="warning",
    )
    db_session.commit()

    assert _count_anomalies(db_session, "thermal_drift") == 1
    assert len(sent) == 1
    assert sent[0][1]["anomaly_type"] == "thermal_drift"
    assert sent[0][1]["severity"] == "warning"
