"""Load 30 days of realistic deployment history so the DORA endpoint and dashboards have data.

    python scripts/seed_deployments.py --url http://localhost:8080
"""

import argparse
import json
import random
import secrets
import urllib.request
from datetime import UTC, datetime, timedelta

SERVICES = ["deploytrack", "payments-api", "web-frontend"]
PROFILE = {"dev": (6, 0.10), "staging": (3, 0.08), "prod": (1.5, 0.05)}  # deploys/day, failure rate


def post(url: str, body: dict) -> None:
    req = urllib.request.Request(  # noqa: S310 local developer tool
        f"{url}/api/v1/deployments",
        data=json.dumps(body).encode(),
        headers={"content-type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=5) as resp:  # noqa: S310
        resp.read()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default="http://localhost:8080")
    parser.add_argument("--days", type=int, default=30)
    parser.add_argument("--seed", type=int, default=7)
    args = parser.parse_args()
    rng = random.Random(args.seed)

    now = datetime.now(UTC)
    count = 0
    for env, (per_day, fail_rate) in PROFILE.items():
        for day in range(args.days):
            for _ in range(rng.randint(0, int(per_day * 2))):
                finished = now - timedelta(days=day, minutes=rng.randint(0, 1439))
                started = finished - timedelta(minutes=rng.randint(3, 12))
                committed = started - timedelta(hours=rng.uniform(0.5, 30))
                post(
                    args.url,
                    {
                        "service": rng.choice(SERVICES),
                        "environment": env,
                        "version": f"1.{day}.{rng.randint(0, 9)}",
                        "commit_sha": secrets.token_hex(20),
                        "status": "failed" if rng.random() < fail_rate else "success",
                        "committed_at": committed.isoformat(),
                        "started_at": started.isoformat(),
                        "finished_at": finished.isoformat(),
                    },
                )
                count += 1
    print(f"seeded {count} deployments into {args.url}")


if __name__ == "__main__":
    main()
