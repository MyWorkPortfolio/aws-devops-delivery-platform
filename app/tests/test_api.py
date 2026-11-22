from datetime import UTC, datetime, timedelta


def test_healthz(client):
    r = client.get("/healthz")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}


def test_readyz(client):
    assert client.get("/readyz").json() == {"status": "ready"}


def test_readyz_returns_503_when_storage_down(client, repo, monkeypatch):
    monkeypatch.setattr(repo, "ping", lambda: False)
    r = client.get("/readyz")
    assert r.status_code == 503


def test_info_exposes_version_and_environment(client):
    assert client.get("/").json() == {"name": "deploytrack", "version": "1.2.3", "environment": "test"}


def test_request_id_is_propagated(client):
    r = client.get("/healthz", headers={"x-request-id": "abc-123"})
    assert r.headers["x-request-id"] == "abc-123"


def test_record_and_list_deployment(client, make_payload):
    r = client.post("/api/v1/deployments", json=make_payload())
    assert r.status_code == 201
    body = r.json()
    assert body["id"]
    assert body["environment"] == "prod"

    listed = client.get("/api/v1/deployments", params={"environment": "prod"}).json()
    assert [d["id"] for d in listed] == [body["id"]]
    assert client.get("/api/v1/deployments", params={"environment": "dev"}).json() == []


def test_rejects_unknown_environment(client, make_payload):
    r = client.post("/api/v1/deployments", json=make_payload(environment="qa"))
    assert r.status_code == 422


def test_rejects_naive_timestamps(client, make_payload):
    payload = make_payload()
    payload["finished_at"] = datetime.now().replace(tzinfo=None).isoformat()
    assert client.post("/api/v1/deployments", json=payload).status_code == 422


def test_rejects_out_of_order_timestamps(client, make_payload):
    payload = make_payload()
    payload["committed_at"] = (datetime.now(UTC) + timedelta(days=1)).isoformat()
    assert client.post("/api/v1/deployments", json=payload).status_code == 422


def test_dora_endpoint(client, make_payload):
    client.post("/api/v1/deployments", json=make_payload())
    r = client.get("/api/v1/dora", params={"environment": "prod", "days": 1})
    assert r.status_code == 200
    report = r.json()
    assert report["deployments"] == 1
    assert report["performance_tier"] == "elite"


def test_metrics_exposed(client, make_payload):
    client.get("/healthz")
    client.post("/api/v1/deployments", json=make_payload(status="failed"))
    text = client.get("/metrics").text
    assert 'http_requests_total{method="GET",route="/healthz",status="200"}' in text
    assert 'deployments_recorded_total{environment="prod",status="failed"} 1.0' in text
    assert 'app_info{environment="test",version="1.2.3"} 1.0' in text
