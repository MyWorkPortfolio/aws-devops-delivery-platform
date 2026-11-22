# ADR 0003: GitHub OIDC with environment scoped roles, no stored AWS keys

**Status:** Accepted

## Decision
GitHub Actions assumes AWS roles through OIDC. There are no AWS access keys in GitHub secrets.

| Role | Trusted subject | Can do |
|---|---|---|
| `deploytrack-github-build` | `repo:<repo>:ref:refs/heads/main` | Push to the one ECR repository |
| `deploytrack-github-deploy-dev` | `repo:<repo>:environment:dev` | Deploy dev |
| `deploytrack-github-deploy-staging` | `repo:<repo>:environment:staging` | Deploy staging |
| `deploytrack-github-deploy-prod` | `repo:<repo>:environment:prod` | Deploy prod |

## Why
* Credentials live for one job and expire after at most an hour.
* The prod role can only be assumed by a job running in the `prod` GitHub Environment, which requires reviewer approval. A compromised branch or PR cannot reach prod.
* Deploy roles can only create and pass IAM roles named `deploytrack-<env>-*`, so the pipeline cannot grant itself new privileges.

## Trade off
Deploy roles use `PowerUserAccess` for service resources. A stricter custom policy is on the roadmap once the resource set stops changing.
