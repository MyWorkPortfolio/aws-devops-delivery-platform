# ADR 0001: ECS Fargate as the AWS runtime, Helm chart kept for Kubernetes

**Status:** Accepted

## Context
The service is a single stateless container. The team needs dev, staging and prod environments on AWS that one engineer can run, alongside a path to Kubernetes if a client already runs EKS.

## Decision
Run on **ECS Fargate** behind an ALB. Ship a **Helm chart** with the same image, probes and security context, tested on every PR in a kind cluster.

## Why
| | ECS Fargate | EKS |
|---|---|---|
| Control plane cost | None | About $73 per month per cluster, times 3 environments |
| Operational surface | Task definition and service | Cluster upgrades, node groups, add ons, ingress controller |
| Fit for one stateless service | Strong | Over provisioned |
| Portability | AWS only | Any conformant cluster |

The chart keeps the portability benefit without paying the EKS cost before it is needed.

## Consequences
* Release safety comes from ECS rolling deploys plus the deployment circuit breaker with automatic rollback.
* `wait_for_steady_state = true` makes `terraform apply` fail when a rollout fails, which stops promotion.
* Moving to EKS later only means pointing the Helm chart at EKS and swapping the task role for IRSA or Pod Identity.
