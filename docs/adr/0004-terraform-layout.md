# ADR 0004: One Terraform root per environment, one shared platform module

**Status:** Accepted

## Options considered
1. **Workspaces** with one root. Rejected: every environment shares one backend config and code path, and it is easy to apply to the wrong workspace.
2. **Copy paste per environment.** Rejected: environments drift.
3. **Thin roots plus a shared module.** Chosen.

## Decision
```
infra/modules/platform   <- composes network, dynamodb, ecs_service, observability
infra/envs/dev           <- 30 line root: sizing knobs only
infra/envs/staging
infra/envs/prod
```
* Each root has its own state file (`deploytrack/<env>/terraform.tfstate`) and its own IAM role.
* State uses S3 native locking (`use_lockfile = true`), so no DynamoDB lock table is needed.
* The backend bucket is passed with `-backend-config`, so no account ID is committed.

## Consequences
dev, staging and prod are structurally identical. The only differences are the values in each `main.tf`, listed in [environments.md](../environments.md).
