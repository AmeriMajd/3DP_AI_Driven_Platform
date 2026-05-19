"""Aggregations for /admin/dashboard endpoints.

All counters scope across every user (admin = platform owner).
Revenue uses `PrintJob.estimated_cost` as proxy on completed jobs.
"""

from datetime import datetime, timedelta, timezone
from typing import Optional

from sqlalchemy import case, func
from sqlalchemy.orm import Session

from app.models.print_job import PrintJob
from app.models.printer import Printer
from app.models.user import User


def _range_days(rng: str) -> Optional[int]:
    return {"7d": 7, "30d": 30, "90d": 90, "all": None}.get(rng, 30)


def _start_of_today_utc() -> datetime:
    now = datetime.now(timezone.utc)
    return datetime(now.year, now.month, now.day, tzinfo=timezone.utc)


class AdminDashboardService:
    def __init__(self, db: Session) -> None:
        self.db = db

    # ── KPIs ────────────────────────────────────────────────
    def kpis(self) -> dict:
        db = self.db

        active_now = (
            db.query(func.count(PrintJob.id))
            .filter(PrintJob.status.in_(["printing", "queued"]))
            .scalar()
            or 0
        )
        printing_now = (
            db.query(func.count(PrintJob.id))
            .filter(PrintJob.status == "printing")
            .scalar()
            or 0
        )
        queued_now = (
            db.query(func.count(PrintJob.id))
            .filter(PrintJob.status == "queued")
            .scalar()
            or 0
        )

        start_today = _start_of_today_utc()
        start_yest = start_today - timedelta(days=1)

        rev_today = (
            db.query(func.coalesce(func.sum(PrintJob.estimated_cost), 0.0))
            .filter(
                PrintJob.status == "completed",
                PrintJob.ended_at >= start_today,
            )
            .scalar()
            or 0.0
        )
        rev_yest = (
            db.query(func.coalesce(func.sum(PrintJob.estimated_cost), 0.0))
            .filter(
                PrintJob.status == "completed",
                PrintJob.ended_at >= start_yest,
                PrintJob.ended_at < start_today,
            )
            .scalar()
            or 0.0
        )

        # success rate over last 30d
        window_start = datetime.now(timezone.utc) - timedelta(days=30)
        prev_window_start = window_start - timedelta(days=30)

        def _success_rate(start: datetime, end: Optional[datetime]) -> float:
            q = db.query(
                func.sum(case((PrintJob.status == "completed", 1), else_=0)),
                func.sum(case((PrintJob.status.in_(["completed", "failed"]), 1), else_=0)),
            ).filter(PrintJob.submitted_at >= start)
            if end is not None:
                q = q.filter(PrintJob.submitted_at < end)
            completed, denom = q.one()
            completed = completed or 0
            denom = denom or 0
            return (completed / denom * 100.0) if denom else 0.0

        sr_now = _success_rate(window_start, None)
        sr_prev = _success_rate(prev_window_start, window_start)

        # queue depth: queued vs prev hour
        queue_prev = (
            db.query(func.count(PrintJob.id))
            .filter(
                PrintJob.status == "queued",
                PrintJob.submitted_at < datetime.now(timezone.utc) - timedelta(hours=1),
            )
            .scalar()
            or 0
        )

        def _delta(curr: float, prev: float) -> float:
            if prev == 0:
                return 0.0 if curr == 0 else 100.0
            return round((curr - prev) / prev * 100.0, 1)

        return {
            "active_jobs": {
                "value": float(active_now),
                "delta_pct": 0.0,
                "sub": f"{printing_now} printing · {queued_now} queued",
            },
            "revenue_today": {
                "value": round(float(rev_today), 2),
                "delta_pct": _delta(rev_today, rev_yest),
                "sub": f"vs ${rev_yest:.0f} yest.",
            },
            "success_rate": {
                "value": round(sr_now, 1),
                "delta_pct": round(sr_now - sr_prev, 1),
                "sub": "last 30 days",
            },
            "queue_depth": {
                "value": float(queued_now),
                "delta_pct": _delta(queued_now, queue_prev),
                "sub": "currently queued",
            },
        }

    # ── revenue per day ─────────────────────────────────────
    def revenue_series(self, rng: str) -> list[dict]:
        days = _range_days(rng) or 90
        start = _start_of_today_utc() - timedelta(days=days - 1)

        rows = (
            self.db.query(
                func.date(PrintJob.ended_at).label("d"),
                func.coalesce(func.sum(PrintJob.estimated_cost), 0.0).label("v"),
            )
            .filter(
                PrintJob.status == "completed",
                PrintJob.ended_at >= start,
            )
            .group_by("d")
            .all()
        )
        by_day = {str(r.d): float(r.v) for r in rows}

        out = []
        for i in range(days):
            d = (start + timedelta(days=i)).date()
            out.append({"date": d.isoformat(), "value": by_day.get(str(d), 0.0)})
        return out

    # ── jobs per day grouped by terminal status ─────────────
    def jobs_by_status_series(self, rng: str) -> list[dict]:
        days = _range_days(rng) or 90
        start = _start_of_today_utc() - timedelta(days=days - 1)

        rows = (
            self.db.query(
                func.date(PrintJob.submitted_at).label("d"),
                PrintJob.status,
                func.count(PrintJob.id).label("n"),
            )
            .filter(PrintJob.submitted_at >= start)
            .group_by("d", PrintJob.status)
            .all()
        )
        buckets: dict[str, dict[str, int]] = {}
        for r in rows:
            buckets.setdefault(str(r.d), {"completed": 0, "failed": 0, "canceled": 0})
            if r.status in ("completed", "failed", "canceled"):
                buckets[str(r.d)][r.status] = int(r.n)

        out = []
        for i in range(days):
            d = (start + timedelta(days=i)).date()
            b = buckets.get(str(d), {"completed": 0, "failed": 0, "canceled": 0})
            out.append({"date": d.isoformat(), **b})
        return out

    # ── active jobs feed ────────────────────────────────────
    def active_jobs(self, limit: int = 12) -> list[dict]:
        q = (
            self.db.query(PrintJob, User, Printer)
            .join(User, User.id == PrintJob.user_id)
            .outerjoin(Printer, Printer.id == PrintJob.printer_id)
            .filter(PrintJob.status.in_(["printing", "queued", "scheduled"]))
            .order_by(PrintJob.status.desc(), PrintJob.submitted_at.desc())
            .limit(limit)
        )
        out = []
        for job, user, printer in q.all():
            out.append(
                {
                    "id": job.id,
                    "user_name": user.full_name,
                    "printer_name": printer.name if printer else "—",
                    "file": None,
                    "status": job.status,
                    "progress_pct": float(job.progress_pct or 0.0),
                    "estimated_cost": job.estimated_cost,
                    "estimated_duration_s": job.estimated_duration_s,
                    "time_left_seconds": job.time_left_seconds,
                    "submitted_at": job.submitted_at,
                }
            )
        return out

    # ── recent jobs (any status), filtered ──────────────────
    def recent_jobs(self, filter_status: Optional[str], limit: int = 20) -> list[dict]:
        q = (
            self.db.query(PrintJob, User, Printer)
            .join(User, User.id == PrintJob.user_id)
            .outerjoin(Printer, Printer.id == PrintJob.printer_id)
            .order_by(PrintJob.submitted_at.desc())
        )
        if filter_status and filter_status != "all":
            q = q.filter(PrintJob.status == filter_status)
        q = q.limit(limit)
        out = []
        for job, user, printer in q.all():
            out.append(
                {
                    "id": job.id,
                    "user_name": user.full_name,
                    "printer_name": printer.name if printer else None,
                    "status": job.status,
                    "estimated_cost": job.estimated_cost,
                    "duration_s": job.actual_duration_s or job.estimated_duration_s,
                    "submitted_at": job.submitted_at,
                }
            )
        return out

    # ── top users by total cost in range ────────────────────
    def top_users(self, rng: str, limit: int = 5) -> list[dict]:
        days = _range_days(rng)
        q = (
            self.db.query(
                User.id,
                User.full_name,
                func.coalesce(func.sum(PrintJob.estimated_cost), 0.0).label("total"),
                func.count(PrintJob.id).label("jobs"),
            )
            .join(PrintJob, PrintJob.user_id == User.id)
            .filter(PrintJob.status == "completed")
        )
        if days is not None:
            start = _start_of_today_utc() - timedelta(days=days - 1)
            q = q.filter(PrintJob.ended_at >= start)
        rows = (
            q.group_by(User.id, User.full_name)
            .order_by(func.sum(PrintJob.estimated_cost).desc())
            .limit(limit)
            .all()
        )
        return [
            {
                "user_id": r.id,
                "full_name": r.full_name,
                "total_cost": round(float(r.total), 2),
                "jobs_count": int(r.jobs),
            }
            for r in rows
        ]
