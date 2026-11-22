# ADR 0002: Build once, promote the same immutable image

**Status:** Accepted

## Context
Rebuilding per environment means prod runs an artifact that was never tested in staging.

## Decision
* The image is built **once** per commit and tagged with the full commit SHA.
* ECR tags are **IMMUTABLE**, so a tag can never point to different bytes.
* The same tag is deployed to dev, then staging, then prod. Only configuration differs.
* Every image gets an SBOM and SLSA provenance attestation at build time.
* Rollback is a redeploy of an earlier SHA through `rollback.yml`. There is no separate rollback mechanism to maintain.

## Consequences
* What passed the staging smoke test is bit for bit what reaches prod.
* The version string the app reports (`GET /`) is the commit SHA, so the smoke test can prove the new version is actually serving.
