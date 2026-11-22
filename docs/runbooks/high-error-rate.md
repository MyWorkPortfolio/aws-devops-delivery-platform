# Runbook: high 5xx error rate

**Alarm:** `deploytrack-<env>-5xx-rate` (CloudWatch) or `DeployTrackHighErrorRate` (Prometheus)
**Fires when:** target 5xx responses exceed 2% of requests in 2 of 3 one minute periods.
**Severity:** critical in prod, warning elsewhere.

## 1. Was there a deploy? (first 2 minutes)
```bash
curl -s "$URL/api/v1/deployments?environment=prod&limit=5" | jq '.[] | {version, status, finished_at}'
```
If a deployment finished in the last 30 minutes, **roll back first, investigate second**:
GitHub → Actions → `rollback` → environment `prod`, image_tag = previous successful SHA.

## 2. Is it every route or one route?
CloudWatch Logs Insights on `/ecs/deploytrack-<env>`:
```
fields @timestamp, route, status, request_id, message
| filter status >= 500
| stats count() by route
| sort count() desc
```

## 3. Is a dependency down?
* `GET /readyz` returns 503 when DynamoDB is unreachable. Check the `dynamodb-throttles` alarm and the AWS Health Dashboard.
* Check the `unhealthy-targets` alarm. If tasks are cycling, see [failed-deployment.md](failed-deployment.md).

## 4. Communicate
Post in the incident channel every 30 minutes: impact, current hypothesis, next action, ETA. Keep the client's account manager informed on status and blockers.

## 5. Afterwards
Within 48 hours, write a blameless post incident review covering timeline, root cause, what detected it, and action items with owners.
