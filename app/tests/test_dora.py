from datetime import UTC, datetime, timedelta

from deploytrack.dora import build_report, classify, recovery_times_hours
from deploytrack.models import Deployment

NOW = datetime(2026, 11, 1, 12, 0, tzinfo=UTC)


def dep(status: str, finished: datetime, lead_hours: float = 2.0, service: str = "api") -> Deployment:
    return Deployment(
        id=f"{service}-{finished.isoformat()}",
        recorded_at=finished,
        service=service,
        environment="prod",
        version="1.0.0",
        commit_sha="abcdef1",
        status=status,
        committed_at=finished - timedelta(hours=lead_hours),
        started_at=finished - timedelta(minutes=5),
        finished_at=finished,
    )


def test_empty_window_is_insufficient_data():
    report = build_report([], "prod", None, 30)
    assert report.performance_tier == "insufficient_data"
    assert report.deployments == 0


def test_change_failure_rate_and_mttr():
    rows = [
        dep("success", NOW),
        dep("failed", NOW + timedelta(hours=1)),
        dep("failed", NOW + timedelta(hours=1, minutes=10)),
        dep("success", NOW + timedelta(hours=1, minutes=30)),
    ]
    report = build_report(rows, "prod", None, 1)
    assert report.change_failure_rate == 0.5
    # recovery measured from the FIRST failure in the streak
    assert report.mttr_hours == 0.5


def test_recovery_is_tracked_per_service():
    rows = [
        dep("failed", NOW, service="a"),
        dep("success", NOW + timedelta(hours=2), service="b"),
        dep("success", NOW + timedelta(hours=3), service="a"),
    ]
    assert recovery_times_hours(rows) == [3.0]


def test_lead_time_uses_successful_deployments_only():
    rows = [dep("success", NOW, lead_hours=4), dep("failed", NOW, lead_hours=100)]
    assert build_report(rows, "prod", None, 7).lead_time_hours_median == 4.0


def test_classification_bands():
    assert classify(2.0, 3.0, 0.1, 0.5) == "elite"
    assert classify(0.5, 30.0, 0.1, None) == "high"
    assert classify(0.05, 300.0, 0.25, 48.0) == "medium"
    assert classify(0.01, 2000.0, 0.6, 500.0) == "low"
    assert classify(5.0, None, None, None) == "low"
