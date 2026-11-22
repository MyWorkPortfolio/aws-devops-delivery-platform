"""DORA metric calculations.

Thresholds follow the bands used in the State of DevOps reports, simplified so they
can be explained in one sentence each. See docs/adr/0005-dora-metrics.md.
"""

from collections import defaultdict
from datetime import datetime
from statistics import median

from .models import Deployment, DeploymentStatus, DoraReport

# (min deploys per day, max lead time hours, max change failure rate, max MTTR hours)
TIERS: tuple[tuple[str, float, float, float, float], ...] = (
    ("elite", 1.0, 24.0, 0.15, 1.0),
    ("high", 1 / 7, 168.0, 0.20, 24.0),
    ("medium", 1 / 30, 720.0, 0.30, 168.0),
)


def _hours(start: datetime, end: datetime) -> float:
    return (end - start).total_seconds() / 3600


def lead_times_hours(deployments: list[Deployment]) -> list[float]:
    return [_hours(d.committed_at, d.finished_at) for d in deployments if d.status is DeploymentStatus.SUCCESS]


def recovery_times_hours(deployments: list[Deployment]) -> list[float]:
    """Time from the first failed deployment of a service to its next successful one."""
    by_service: dict[str, list[Deployment]] = defaultdict(list)
    for d in deployments:
        by_service[d.service].append(d)

    recoveries: list[float] = []
    for items in by_service.values():
        failure_started: datetime | None = None
        for d in sorted(items, key=lambda x: x.finished_at):
            if d.status is DeploymentStatus.FAILED and failure_started is None:
                failure_started = d.finished_at
            elif d.status is DeploymentStatus.SUCCESS and failure_started is not None:
                recoveries.append(_hours(failure_started, d.finished_at))
                failure_started = None
    return recoveries


def classify(frequency: float, lead_time: float | None, cfr: float | None, mttr: float | None) -> str:
    if lead_time is None:
        return "low"
    for name, min_freq, max_lead, max_cfr, max_mttr in TIERS:
        if (
            frequency >= min_freq
            and lead_time <= max_lead
            and (cfr is None or cfr <= max_cfr)
            and (mttr is None or mttr <= max_mttr)
        ):
            return name
    return "low"


def build_report(deployments: list[Deployment], environment: str, service: str | None, window_days: int) -> DoraReport:
    total = len(deployments)
    if total == 0:
        return DoraReport(
            environment=environment,
            service=service,
            window_days=window_days,
            deployments=0,
            deployment_frequency_per_day=0.0,
            lead_time_hours_median=None,
            change_failure_rate=None,
            mttr_hours=None,
            performance_tier="insufficient_data",
        )

    failed = sum(1 for d in deployments if d.status is DeploymentStatus.FAILED)
    leads = lead_times_hours(deployments)
    recoveries = recovery_times_hours(deployments)

    frequency = total / window_days
    lead = median(leads) if leads else None
    cfr = failed / total
    mttr = sum(recoveries) / len(recoveries) if recoveries else None

    return DoraReport(
        environment=environment,
        service=service,
        window_days=window_days,
        deployments=total,
        deployment_frequency_per_day=round(frequency, 3),
        lead_time_hours_median=round(lead, 2) if lead is not None else None,
        change_failure_rate=round(cfr, 3),
        mttr_hours=round(mttr, 2) if mttr is not None else None,
        performance_tier=classify(frequency, lead, cfr, mttr),
    )
