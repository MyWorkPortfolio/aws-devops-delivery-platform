"""HTTP API. Start with: uvicorn --factory deploytrack.main:create_app"""

import logging
import time
import uuid
from datetime import UTC, datetime, timedelta

from fastapi import FastAPI, Query, Request, Response
from prometheus_client import CONTENT_TYPE_LATEST, CollectorRegistry, Counter, Gauge, Histogram, generate_latest

from .config import Settings, get_settings
from .dora import build_report
from .logging_config import configure_logging
from .models import Deployment, DeploymentIn, DoraReport, Environment
from .repository import DeploymentRepository, DynamoDBRepository, InMemoryRepository

log = logging.getLogger("deploytrack")


def build_repository(settings: Settings) -> DeploymentRepository:
    if settings.storage_backend == "dynamodb":
        return DynamoDBRepository(
            table_name=settings.dynamodb_table,
            region=settings.aws_region,
            endpoint_url=settings.dynamodb_endpoint_url,
        )
    return InMemoryRepository()


def create_app(settings: Settings | None = None, repository: DeploymentRepository | None = None) -> FastAPI:
    settings = settings or get_settings()
    repo = repository or build_repository(settings)
    configure_logging(
        settings.log_level, service=settings.app_name, environment=settings.environment, version=settings.version
    )

    app = FastAPI(title="DeployTrack", version=settings.version, docs_url="/docs", redoc_url=None)

    registry = CollectorRegistry()
    http_requests = Counter("http_requests_total", "HTTP requests", ["method", "route", "status"], registry=registry)
    http_latency = Histogram(
        "http_request_duration_seconds",
        "HTTP request latency",
        ["method", "route"],
        buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5),
        registry=registry,
    )
    deployments_recorded = Counter(
        "deployments_recorded_total", "Deployments recorded", ["environment", "status"], registry=registry
    )
    Gauge("app_info", "Build information", ["version", "environment"], registry=registry).labels(
        settings.version, settings.environment
    ).set(1)

    @app.middleware("http")
    async def observe(request: Request, call_next):
        request_id = request.headers.get("x-request-id") or str(uuid.uuid4())
        start = time.perf_counter()
        status = 500
        try:
            response = await call_next(request)
            status = response.status_code
            response.headers["x-request-id"] = request_id
            return response
        except Exception:
            log.exception("unhandled_error", extra={"request_id": request_id, "path": request.url.path})
            raise
        finally:
            elapsed = time.perf_counter() - start
            route = getattr(request.scope.get("route"), "path", "unmatched")
            if route != "/metrics":
                http_requests.labels(request.method, route, str(status)).inc()
                http_latency.labels(request.method, route).observe(elapsed)
            if route not in ("/healthz", "/metrics"):
                log.info(
                    "request",
                    extra={
                        "request_id": request_id,
                        "method": request.method,
                        "route": route,
                        "status": status,
                        "duration_ms": round(elapsed * 1000, 2),
                    },
                )

    @app.get("/", include_in_schema=False)
    def info() -> dict[str, str]:
        return {"name": settings.app_name, "version": settings.version, "environment": settings.environment}

    @app.get("/healthz", tags=["ops"])
    def healthz() -> dict[str, str]:
        """Liveness: the process is up. Never touches dependencies."""
        return {"status": "ok"}

    @app.get("/readyz", tags=["ops"])
    def readyz(response: Response) -> dict[str, str]:
        """Readiness: dependencies are reachable, so the load balancer may send traffic."""
        if repo.ping():
            return {"status": "ready"}
        response.status_code = 503
        return {"status": "storage_unavailable"}

    @app.get("/metrics", include_in_schema=False)
    def metrics() -> Response:
        return Response(generate_latest(registry), media_type=CONTENT_TYPE_LATEST)

    @app.post("/api/v1/deployments", status_code=201, response_model=Deployment, tags=["deployments"])
    def record_deployment(body: DeploymentIn) -> Deployment:
        deployment = Deployment(**body.model_dump(), id=str(uuid.uuid4()), recorded_at=datetime.now(UTC))
        repo.add(deployment)
        deployments_recorded.labels(deployment.environment, deployment.status.value).inc()
        log.info("deployment_recorded", extra={"deployment_id": deployment.id, "target": deployment.environment})
        return deployment

    @app.get("/api/v1/deployments", response_model=list[Deployment], tags=["deployments"])
    def list_deployments(
        environment: Environment | None = None,
        service: str | None = None,
        limit: int = Query(50, ge=1, le=500),
    ) -> list[Deployment]:
        return repo.list(environment=environment, service=service, limit=limit)

    @app.get("/api/v1/dora", response_model=DoraReport, tags=["dora"])
    def dora(
        environment: Environment = "prod",
        service: str | None = None,
        days: int = Query(30, ge=1, le=365),
    ) -> DoraReport:
        since = datetime.now(UTC) - timedelta(days=days)
        rows = repo.list(environment=environment, service=service, since=since, limit=10_000)
        return build_report(rows, environment, service, days)

    return app
