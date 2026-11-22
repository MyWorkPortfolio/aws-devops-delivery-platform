#!/usr/bin/env bash
# The pipeline records every deployment into DeployTrack itself, so the platform
# measures its own DORA metrics. Never fails the pipeline: metrics are best effort.
#
# Required env: DEPLOYTRACK_URL ENVIRONMENT VERSION COMMIT_SHA STATUS COMMITTED_AT STARTED_AT
set -uo pipefail

FINISHED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

payload="$(cat <<JSON
{
  "service": "deploytrack",
  "environment": "${ENVIRONMENT}",
  "version": "${VERSION}",
  "commit_sha": "${COMMIT_SHA}",
  "status": "${STATUS}",
  "committed_at": "${COMMITTED_AT}",
  "started_at": "${STARTED_AT}",
  "finished_at": "${FINISHED_AT}"
}
JSON
)"

if curl -fsS --max-time 10 -X POST "${DEPLOYTRACK_URL}/api/v1/deployments" \
     -H 'content-type: application/json' -d "$payload" >/dev/null; then
  echo "recorded ${STATUS} deployment of ${VERSION} to ${ENVIRONMENT}"
else
  echo "::warning::could not record deployment in DeployTrack"
fi
