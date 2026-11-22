"""Twelve factor configuration. Every setting comes from DEPLOYTRACK_* environment variables."""

from functools import lru_cache
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="DEPLOYTRACK_", extra="ignore")

    app_name: str = "deploytrack"
    environment: str = "local"
    version: str = "0.0.0-dev"
    log_level: str = "INFO"

    storage_backend: Literal["memory", "dynamodb"] = "memory"
    dynamodb_table: str = "deploytrack-local"
    aws_region: str = "us-east-1"
    dynamodb_endpoint_url: str | None = None


@lru_cache
def get_settings() -> Settings:
    return Settings()
