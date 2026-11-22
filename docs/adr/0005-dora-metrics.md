# ADR 0005: The platform measures its own delivery performance

**Status:** Accepted

## Decision
The sample workload is DeployTrack, a service that records deployments and reports the four DORA metrics. Every pipeline run posts its own outcome to the environment it just deployed.

| Metric | How it is calculated |
|---|---|
| Deployment frequency | deployments in window / days in window |
| Lead time for changes | median of `finished_at - committed_at` over successful deployments |
| Change failure rate | failed deployments / all deployments |
| Time to restore | mean time from the first failure in a streak to the next success, per service |

Performance tiers use simplified State of DevOps bands: elite, high, medium, low.

## Why
A demo app that does nothing teaches nothing. This one turns the pipeline into data, so the question "how good is our delivery?" gets a number instead of an opinion.

## Storage
DynamoDB single table design, `pk = ENV#<env>`, `sk = <finished_at>#<id>`. A window query is one `Query` with a key condition, never a `Scan`.
