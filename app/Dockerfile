# syntax=docker/dockerfile:1.7

# ---- build stage: resolve dependencies once, cached by requirements.txt ----
FROM python:3.15-slim AS build
WORKDIR /build
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --prefix=/install -r requirements.txt

# ---- runtime stage: no compilers, no pip cache, non root user ----
FROM python:3.15-slim AS runtime

ARG APP_VERSION=0.0.0-dev
ARG GIT_SHA=unknown
LABEL org.opencontainers.image.title="deploytrack" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.revision="${GIT_SHA}" \
      org.opencontainers.image.source="https://github.com/MyWorkPortfolio/aws-devops-delivery-platform"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app/src \
    DEPLOYTRACK_VERSION=${APP_VERSION}

# Pick up Debian security fixes published after the base image was built.
RUN apt-get update \
 && apt-get upgrade -y --no-install-recommends \
 && rm -rf /var/lib/apt/lists/* \
 && groupadd --system --gid 10001 app \
 && useradd --system --uid 10001 --gid app --no-create-home app

COPY --from=build /install /usr/local
WORKDIR /app
COPY src ./src

USER 10001
EXPOSE 8080

HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/healthz', timeout=2)"]

CMD ["uvicorn", "--factory", "deploytrack.main:create_app", "--host", "0.0.0.0", "--port", "8080", "--no-access-log", "--proxy-headers"]
