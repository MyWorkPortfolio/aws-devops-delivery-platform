# Environments

All three environments are built from the same `infra/modules/platform` module. These are the only differences:

| Setting | dev | staging | prod | Why |
|---|---|---|---|---|
| VPC CIDR | 10.10.0.0/16 | 10.20.0.0/16 | 10.30.0.0/16 | Non overlapping, so peering or a transit gateway stays possible |
| Availability zones | 2 | 2 | 3 | prod survives a zone loss with capacity to spare |
| NAT gateways | 1 shared | 1 shared | 1 per AZ | The largest fixed cost; HA only where it pays off |
| Task size | 0.25 vCPU / 512 MiB | 0.25 vCPU / 512 MiB | 0.5 vCPU / 1 GiB | |
| Tasks min to max | 1 to 2 | 2 to 4 | 3 to 10 | staging runs 2 so rolling deploys behave like prod |
| Capacity | Fargate Spot | Fargate Spot | Fargate on demand | Spot interruptions are acceptable below prod |
| Log retention | 7 days | 14 days | 90 days | |
| Deletion protection | off | off | on (ALB and DynamoDB) | |
| p95 latency alarm | 1.0 s | 0.5 s | 0.5 s | |
| Deploy trigger | Every merge to main | After dev passes | After staging passes **and** reviewer approval | |

## Promotion rules
1. A change reaches **dev** only after all CI jobs pass on the PR.
2. **staging** receives the same image only if the dev smoke test passed.
3. **prod** waits for a required reviewer on the `prod` GitHub Environment.
4. A failed smoke test at any stage stops promotion and is recorded as a failed deployment.

## Approximate monthly cost (us-east-1 list prices, light traffic)
| | dev | staging | prod |
|---|---|---|---|
| NAT gateway(s) | about $33 | about $33 | about $99 |
| ALB | about $17 | about $17 | about $20 |
| Fargate | about $3 (Spot) | about $6 (Spot) | about $55 |
| DynamoDB, CloudWatch, SNS | under $5 | under $5 | under $10 |

Check current prices with the AWS Pricing Calculator. Run `terraform destroy` on dev and staging when you're not using them.
