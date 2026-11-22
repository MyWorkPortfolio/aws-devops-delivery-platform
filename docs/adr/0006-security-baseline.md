# ADR 0006: Security baseline and accepted exceptions

**Status:** Accepted

## Controls in place
* Tasks run in private subnets with no public IP. Their security group only accepts traffic from the ALB security group.
* The default VPC security group is stripped of all rules. Rejected traffic is captured in VPC flow logs.
* The task role allows exactly `PutItem`, `Query` and `DescribeTable` on one table.
* The container runs as non root UID 10001 with a read only root filesystem. On Kubernetes, all capabilities are dropped and seccomp is set to RuntimeDefault.
* The ALB drops invalid headers. When a certificate is supplied, it serves TLS 1.3 and redirects HTTP to HTTPS.
* DynamoDB has point in time recovery and encryption at rest, plus deletion protection in prod.
* Terraform state is versioned, KMS encrypted and TLS only, with public access blocked.
* CI scans every image with Grype (failing on fixable high or critical CVEs) and every Terraform change with checkov. GitHub Actions are pinned to commit SHAs, and Dependabot keeps every dependency current.

## Accepted checkov exceptions
Each one is listed with its reason in [`.checkov.yaml`](../../.checkov.yaml). In short:
* **HTTP listener:** stays until a domain exists, then setting `certificate_arn` switches to HTTPS.
* **Customer managed KMS keys:** AWS managed keys already encrypt the data, and CMKs add cost and key policy overhead.
* **Log retention under one year:** a cost decision made per environment.
* **ALB access logs and WAF:** planned for prod.
