.DEFAULT_GOAL := help
SHELL := /bin/bash
APP := app
ENVS := dev staging prod

help: ## Show targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

# ---- application ----------------------------------------------------------
install: ## Create venv and install dev dependencies
	python3 -m venv .venv && . .venv/bin/activate && pip install -r $(APP)/requirements-dev.txt

lint: ## Ruff lint and format check
	cd $(APP) && ruff check . && ruff format --check .

test: ## Unit and integration tests with coverage gate
	cd $(APP) && pytest

run: ## Run the API locally with in memory storage on :8080
	cd $(APP) && PYTHONPATH=src uvicorn --factory deploytrack.main:create_app --reload --port 8080

# ---- local stack ----------------------------------------------------------
up: ## Start app, DynamoDB local, Prometheus and Grafana
	docker compose up -d --build
	@echo "API http://localhost:8080/docs  Prometheus http://localhost:9090  Grafana http://localhost:3000"

seed: ## Load 30 days of sample deployments
	python3 scripts/seed_deployments.py --url http://localhost:8080

smoke: ## Smoke test the local stack
	scripts/smoke_test.sh http://localhost:8080 local 60

down: ## Stop the local stack
	docker compose down -v

# ---- kubernetes -----------------------------------------------------------
kind-up: ## Create kind cluster, load image, install chart
	kind create cluster --config deploy/kind/cluster.yaml
	docker build -t deploytrack:local --build-arg APP_VERSION=local $(APP)
	kind load docker-image deploytrack:local --name deploytrack
	helm upgrade --install dt deploy/helm/deploytrack -f deploy/helm/deploytrack/values-kind.yaml --wait

kind-down: ## Delete the kind cluster
	kind delete cluster --name deploytrack

# ---- infrastructure -------------------------------------------------------
tf-fmt: ## Format all Terraform
	terraform fmt -recursive infra

tf-validate: ## Validate every Terraform root without a backend
	@for d in infra/bootstrap $(addprefix infra/envs/,$(ENVS)); do \
		terraform -chdir=$$d init -backend=false -input=false >/dev/null && terraform -chdir=$$d validate || exit 1; \
	done

tf-lint: ## tflint and checkov
	cd infra && tflint --init --config ../.tflint.hcl && tflint --recursive --config $(CURDIR)/.tflint.hcl
	checkov --config-file .checkov.yaml -d infra

check: lint test tf-validate tf-lint ## Everything CI runs that does not need Docker

.PHONY: help install lint test run up seed smoke down kind-up kind-down tf-fmt tf-validate tf-lint check
