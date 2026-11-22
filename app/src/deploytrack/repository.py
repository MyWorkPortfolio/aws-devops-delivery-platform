"""Storage backends.

DynamoDB key design (single table, no scans):
    PK = "ENV#<environment>"
    SK = "<finished_at ISO 8601 UTC>#<id>"
Listing an environment for a time window is a single Query on PK with SK >= since.
"""

from __future__ import annotations

import threading
from datetime import datetime
from typing import Any, Protocol

from .models import ENVIRONMENTS, Deployment


class DeploymentRepository(Protocol):
    def add(self, deployment: Deployment) -> None: ...

    def list(
        self,
        environment: str | None = None,
        service: str | None = None,
        since: datetime | None = None,
        limit: int = 500,
    ) -> list[Deployment]: ...

    def ping(self) -> bool: ...


def _matches(d: Deployment, environment: str | None, service: str | None, since: datetime | None) -> bool:
    return (
        (environment is None or d.environment == environment)
        and (service is None or d.service == service)
        and (since is None or d.finished_at >= since)
    )


class InMemoryRepository:
    """Used for local development and tests."""

    def __init__(self) -> None:
        self._items: list[Deployment] = []
        self._lock = threading.Lock()

    def add(self, deployment: Deployment) -> None:
        with self._lock:
            self._items.append(deployment)

    def list(self, environment=None, service=None, since=None, limit=500) -> list[Deployment]:
        with self._lock:
            rows = [d for d in self._items if _matches(d, environment, service, since)]
        rows.sort(key=lambda d: d.finished_at, reverse=True)
        return rows[:limit]

    def ping(self) -> bool:
        return True


class DynamoDBRepository:
    def __init__(self, table_name: str, region: str, endpoint_url: str | None = None, resource: Any = None) -> None:
        if resource is None:
            import boto3

            resource = boto3.resource("dynamodb", region_name=region, endpoint_url=endpoint_url)
        self._table = resource.Table(table_name)

    @staticmethod
    def _to_item(d: Deployment) -> dict[str, Any]:
        item = d.model_dump(mode="json")
        item["pk"] = f"ENV#{d.environment}"
        item["sk"] = f"{d.finished_at.isoformat()}#{d.id}"
        return item

    @staticmethod
    def _from_item(item: dict[str, Any]) -> Deployment:
        data = {k: v for k, v in item.items() if k not in ("pk", "sk")}
        return Deployment.model_validate(data)

    def add(self, deployment: Deployment) -> None:
        self._table.put_item(
            Item=self._to_item(deployment),
            ConditionExpression="attribute_not_exists(pk)",
        )

    def _query_env(self, environment: str, service: str | None, since: datetime | None, limit: int) -> list[Deployment]:
        from boto3.dynamodb.conditions import Attr, Key

        key = Key("pk").eq(f"ENV#{environment}")
        if since is not None:
            key = key & Key("sk").gte(since.isoformat())
        kwargs: dict[str, Any] = {"KeyConditionExpression": key, "ScanIndexForward": False}
        if service is not None:
            kwargs["FilterExpression"] = Attr("service").eq(service)

        results: list[Deployment] = []
        while True:
            page = self._table.query(**kwargs)
            results.extend(self._from_item(i) for i in page.get("Items", []))
            if len(results) >= limit or "LastEvaluatedKey" not in page:
                break
            kwargs["ExclusiveStartKey"] = page["LastEvaluatedKey"]
        return results[:limit]

    def list(self, environment=None, service=None, since=None, limit=500) -> list[Deployment]:
        envs = [environment] if environment else list(ENVIRONMENTS)
        rows: list[Deployment] = []
        for env in envs:
            rows.extend(self._query_env(env, service, since, limit))
        rows.sort(key=lambda d: d.finished_at, reverse=True)
        return rows[:limit]

    def ping(self) -> bool:
        try:
            self._table.load()
            return True
        except Exception:  # noqa: BLE001 readiness must never raise
            return False
