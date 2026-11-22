# Runbook: high p95 latency

**Alarm:** `deploytrack-<env>-latency-p95` or `DeployTrackHighLatency`
**Fires when:** ALB target p95 response time is above the environment threshold (500 ms in staging and prod) for 3 of 5 minutes.

## Triage
1. **Saturation?** Open the dashboard `deploytrack-<env>`. If CPU or memory is above 80% and the task count is at `max_count`, autoscaling is capped. Raise `max_count` in `infra/envs/<env>/main.tf` and deploy.
2. **One route?** Run this in Logs Insights:
   ```
   fields route, duration_ms
   | stats pct(duration_ms, 95) as p95 by route
   | sort p95 desc
   ```
   `/api/v1/dora` with a large `days` window is the most expensive call, because it queries and aggregates in memory.
3. **DynamoDB?** Check `SuccessfulRequestLatency` for the table. Throttling shows up on the `dynamodb-throttles` alarm.
4. **Recent deploy?** Compare p95 before and after the last entry in `/api/v1/deployments`. If the new version is slower, roll back.

## Longer term fixes
Cache DORA reports per (environment, window) for 60 seconds, or precompute them on write.
