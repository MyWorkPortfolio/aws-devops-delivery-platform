"""API and domain models."""

from datetime import UTC, datetime
from enum import StrEnum
from typing import Literal

from pydantic import BaseModel, Field, field_validator, model_validator

Environment = Literal["dev", "staging", "prod"]
ENVIRONMENTS: tuple[str, ...] = ("dev", "staging", "prod")


class DeploymentStatus(StrEnum):
    SUCCESS = "success"
    FAILED = "failed"


class DeploymentIn(BaseModel):
    """A deployment event, usually posted by the CD pipeline after each rollout."""

    service: str = Field(min_length=1, max_length=64, pattern=r"^[a-z0-9][a-z0-9-]*$")
    environment: Environment
    version: str = Field(min_length=1, max_length=128)
    commit_sha: str = Field(pattern=r"^[0-9a-f]{7,40}$")
    status: DeploymentStatus
    committed_at: datetime
    started_at: datetime
    finished_at: datetime

    @field_validator("committed_at", "started_at", "finished_at")
    @classmethod
    def _require_timezone(cls, value: datetime) -> datetime:
        if value.tzinfo is None:
            raise ValueError("timestamps must include a timezone offset")
        return value.astimezone(UTC)

    @model_validator(mode="after")
    def _check_ordering(self) -> "DeploymentIn":
        if not self.committed_at <= self.started_at <= self.finished_at:
            raise ValueError("expected committed_at <= started_at <= finished_at")
        return self


class Deployment(DeploymentIn):
    id: str
    recorded_at: datetime


class DoraReport(BaseModel):
    environment: Environment
    service: str | None
    window_days: int
    deployments: int
    deployment_frequency_per_day: float
    lead_time_hours_median: float | None
    change_failure_rate: float | None
    mttr_hours: float | None
    performance_tier: Literal["elite", "high", "medium", "low", "insufficient_data"]
