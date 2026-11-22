"""Structured JSON logs so CloudWatch Logs Insights and Grafana Loki can query fields directly."""

import json
import logging
import sys
from datetime import UTC, datetime

_RESERVED = set(logging.LogRecord("", 0, "", 0, "", (), None).__dict__) | {"message"}


class JsonFormatter(logging.Formatter):
    def __init__(self, static_fields: dict[str, str]) -> None:
        super().__init__()
        self._static = static_fields

    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "timestamp": datetime.fromtimestamp(record.created, UTC).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            **self._static,
        }
        payload.update({k: v for k, v in record.__dict__.items() if k not in _RESERVED})
        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)
        return json.dumps(payload, default=str)


def configure_logging(level: str, **static_fields: str) -> None:
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonFormatter(static_fields))
    root = logging.getLogger()
    root.handlers[:] = [handler]
    root.setLevel(level.upper())
