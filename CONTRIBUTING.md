# Shipping a change

This is the workflow for developers on the team. From laptop to prod is normally under an hour.

1. **Branch** from `main`, then run `make install` once.
2. **Develop locally** against the real stack: `make up && make seed`, then open http://localhost:8080/docs. Grafana at http://localhost:3000 shows your requests live.
3. **Check before pushing:** run `make check` (lint, tests, Terraform validate, tflint, checkov). Optionally install the pre-commit hooks with `pre-commit install`.
4. **Open a PR.** CI runs five jobs: app tests, container build and scan, Terraform checks, a Helm deploy into a kind cluster, and workflow lint. All five must be green to merge.
5. **Merge.** The image is built once and deployed to dev, then staging, automatically. Watch the run in Actions; each stage links to its environment URL.
6. **Prod.** A reviewer approves the `prod` environment in the Actions run, and the same image is promoted.
7. **Check delivery health** at `GET /api/v1/dora?environment=prod`.

If something breaks after release, follow [docs/runbooks/failed-deployment.md](docs/runbooks/failed-deployment.md). Rollback is one click.
