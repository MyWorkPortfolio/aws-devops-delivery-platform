#!/usr/bin/env bash
# Post deployment smoke test. Fails the pipeline (and so blocks promotion) unless
# the new version is live, healthy and ready within the timeout.
#
#   scripts/smoke_test.sh <base_url> [expected_version] [timeout_seconds]
set -euo pipefail

BASE_URL="${1:?usage: smoke_test.sh <base_url> [expected_version] [timeout_seconds]}"
EXPECTED_VERSION="${2:-}"
TIMEOUT="${3:-300}"
deadline=$((SECONDS + TIMEOUT))

log() { printf '[smoke] %s\n' "$*"; }

wait_for() {
  local path="$1" want="$2"
  until body="$(curl -fsS --max-time 5 "${BASE_URL}${path}" 2>/dev/null)" && grep -q "$want" <<<"$body"; do
    if (( SECONDS >= deadline )); then
      log "FAIL ${path} did not return ${want} within ${TIMEOUT}s (last body: ${body:-none})"
      exit 1
    fi
    sleep 5
  done
  log "ok   ${path} -> ${body}"
}

wait_for /healthz '"ok"'
wait_for /readyz '"ready"'
if [[ -n "$EXPECTED_VERSION" ]]; then
  # During a rolling deploy old tasks still answer, so wait until the new version serves.
  wait_for / "\"version\":\"${EXPECTED_VERSION}\""
fi

code="$(curl -s -o /dev/null -w '%{http_code}' "${BASE_URL}/api/v1/dora?days=1")"
[[ "$code" == "200" ]] || { log "FAIL /api/v1/dora returned ${code}"; exit 1; }
log "ok   /api/v1/dora -> 200"
log "PASS ${BASE_URL}"
