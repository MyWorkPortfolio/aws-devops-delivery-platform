from datetime import UTC, datetime, timedelta

import pytest
from fastapi.testclient import TestClient

from deploytrack.config import Settings
from deploytrack.main import create_app
from deploytrack.repository import InMemoryRepository


@pytest.fixture
def repo() -> InMemoryRepository:
    return InMemoryRepository()


@pytest.fixture
def client(repo: InMemoryRepository) -> TestClient:
    settings = Settings(environment="test", version="1.2.3", storage_backend="memory")
    return TestClient(create_app(settings=settings, repository=repo))


@pytest.fixture
def make_payload():
    def _make(
        status: str = "success",
        environment: str = "prod",
        service: str = "deploytrack",
        lead_hours: float = 2.0,
        finished: datetime | None = None,
    ) -> dict:
        finished = finished or datetime.now(UTC) - timedelta(hours=1)
        started = finished - timedelta(minutes=5)
        committed = finished - timedelta(hours=lead_hours)
        return {
            "service": service,
            "environment": environment,
            "version": "1.0.0",
            "commit_sha": "a1b2c3d4e5f6",
            "status": status,
            "committed_at": committed.isoformat(),
            "started_at": started.isoformat(),
            "finished_at": finished.isoformat(),
        }

    return _make
