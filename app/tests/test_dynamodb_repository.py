"""Exercises the real DynamoDB key design against moto, including the condition on put."""

import uuid
from datetime import UTC, datetime, timedelta

import boto3
import pytest
from moto import mock_aws

from deploytrack.models import Deployment
from deploytrack.repository import DynamoDBRepository

TABLE = "deploytrack-test"


@pytest.fixture
def ddb_repo(monkeypatch):
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "testing")
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "testing")
    with mock_aws():
        resource = boto3.resource("dynamodb", region_name="us-east-1")
        resource.create_table(
            TableName=TABLE,
            KeySchema=[{"AttributeName": "pk", "KeyType": "HASH"}, {"AttributeName": "sk", "KeyType": "RANGE"}],
            AttributeDefinitions=[
                {"AttributeName": "pk", "AttributeType": "S"},
                {"AttributeName": "sk", "AttributeType": "S"},
            ],
            BillingMode="PAY_PER_REQUEST",
        )
        yield DynamoDBRepository(TABLE, "us-east-1", resource=resource)


def make(env: str, service: str, finished: datetime) -> Deployment:
    return Deployment(
        id=str(uuid.uuid4()),
        recorded_at=finished,
        service=service,
        environment=env,
        version="1.0.0",
        commit_sha="abcdef1",
        status="success",
        committed_at=finished - timedelta(hours=1),
        started_at=finished - timedelta(minutes=5),
        finished_at=finished,
    )


def test_round_trip_and_filters(ddb_repo):
    now = datetime.now(UTC)
    old = make("prod", "api", now - timedelta(days=40))
    recent = make("prod", "api", now - timedelta(days=1))
    other_service = make("prod", "worker", now - timedelta(hours=2))
    staging = make("staging", "api", now)
    for d in (old, recent, other_service, staging):
        ddb_repo.add(d)

    prod = ddb_repo.list(environment="prod")
    assert [d.id for d in prod] == [other_service.id, recent.id, old.id]

    windowed = ddb_repo.list(environment="prod", since=now - timedelta(days=30))
    assert {d.id for d in windowed} == {recent.id, other_service.id}

    assert [d.id for d in ddb_repo.list(environment="prod", service="worker")] == [other_service.id]
    assert len(ddb_repo.list()) == 4
    assert len(ddb_repo.list(limit=2)) == 2
    assert prod[0] == other_service


def test_put_is_idempotent_guarded(ddb_repo):
    d = make("dev", "api", datetime.now(UTC))
    ddb_repo.add(d)
    with pytest.raises(Exception, match="ConditionalCheckFailed"):
        ddb_repo.add(d)


def test_ping(ddb_repo):
    assert ddb_repo.ping() is True


def test_ping_false_when_table_missing(monkeypatch):
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "testing")
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "testing")
    with mock_aws():
        repo = DynamoDBRepository("missing", "us-east-1", resource=boto3.resource("dynamodb", region_name="us-east-1"))
        assert repo.ping() is False
