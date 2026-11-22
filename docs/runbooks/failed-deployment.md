# Runbook: failed deployment and rollback

## How failure is contained automatically
1. **ECS circuit breaker.** If new tasks fail container or ALB health checks, ECS stops the rollout and rolls back to the last healthy task definition.
2. **`wait_for_steady_state`.** `terraform apply` fails, so the pipeline stops before the next environment.
3. **Smoke test.** If the new SHA is not the version serving `GET /`, the job fails, and promotion to the next environment never happens.
4. Every outcome is recorded in DeployTrack, so a failure counts toward the change failure rate.

## Manual rollback
GitHub → Actions → **rollback** → choose the environment → paste the last known good 40 character SHA. To find it:
```bash
curl -s "$URL/api/v1/deployments?environment=prod&limit=10" \
  | jq -r '.[] | select(.status=="success") | .version' | head -2
```
The second line is the previous good version. The image already exists in ECR (immutable tags), so a rollback takes as long as one rolling deploy, typically 3 to 5 minutes.

## Investigating why tasks would not start
```bash
aws ecs describe-services --cluster deploytrack-prod --services deploytrack-prod \
  --query 'services[0].events[:10].[createdAt,message]' --output table
aws ecs list-tasks --cluster deploytrack-prod --desired-status STOPPED
aws ecs describe-tasks --cluster deploytrack-prod --tasks <arn> --query 'tasks[0].stoppedReason'
```
Common causes: the image tag is missing from ECR, the task role lacks permission (shows as `/readyz` 503), or a container exits on bad config (check `/ecs/deploytrack-prod`).

## Terraform state lock stuck
S3 native locking leaves a `.tflock` object if a run is killed mid apply. First confirm no other run is active in GitHub Actions, then:
```bash
terraform force-unlock <LOCK_ID>
```
