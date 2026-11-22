# One time, per AWS account. Creates what every environment and the pipeline depend on:
#   1. S3 bucket for Terraform state (versioned, encrypted, TLS only)
#   2. ECR repository with immutable tags and scan on push
#   3. GitHub OIDC provider and IAM roles, so CI never stores AWS keys
#
# Run locally with an admin profile:  terraform init && terraform apply -var github_repository=MyWorkPortfolio/aws-devops-delivery-platform

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "deploytrack"
      ManagedBy = "terraform"
      Stack     = "bootstrap"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  account_id   = data.aws_caller_identity.current.account_id
  state_bucket = coalesce(var.state_bucket_name, "deploytrack-tfstate-${local.account_id}")
  environments = toset(["dev", "staging", "prod"])
}

# ---------------------------------------------------------------------------
# Terraform state
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "state" {
  bucket = local.state_bucket
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

data "aws_iam_policy_document" "state_tls_only" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*",
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state_tls_only.json
}

# ---------------------------------------------------------------------------
# Container registry: build once, promote the same digest everywhere
# ---------------------------------------------------------------------------
resource "aws_ecr_repository" "app" {
  name                 = "deploytrack"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the last 50 images"
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 50 }
      action       = { type = "expire" }
    }]
  })
}

# ---------------------------------------------------------------------------
# GitHub Actions OIDC: short lived credentials, scoped per job
# ---------------------------------------------------------------------------
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# Build role: only the main branch may push images.
data "aws_iam_policy_document" "build_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "build" {
  name               = "deploytrack-github-build"
  assume_role_policy = data.aws_iam_policy_document.build_trust.json
}

data "aws_iam_policy_document" "build" {
  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid = "EcrPush"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [aws_ecr_repository.app.arn]
  }
}

resource "aws_iam_role_policy" "build" {
  name   = "push-images"
  role   = aws_iam_role.build.id
  policy = data.aws_iam_policy_document.build.json
}

# Deploy roles: one per environment. The OIDC subject pins each role to its
# GitHub Environment, so only a job running in the "prod" environment, after
# its required reviewers approve, can assume the prod role.
data "aws_iam_policy_document" "deploy_trust" {
  for_each = local.environments

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:environment:${each.key}"]
    }
  }
}

resource "aws_iam_role" "deploy" {
  for_each = local.environments

  name                 = "deploytrack-github-deploy-${each.key}"
  assume_role_policy   = data.aws_iam_policy_document.deploy_trust[each.key].json
  max_session_duration = 3600
}

# PowerUserAccess covers the service resources. IAM is granted separately and only
# for roles named deploytrack-*, so the pipeline cannot escalate its own privileges.
resource "aws_iam_role_policy_attachment" "deploy_power_user" {
  for_each   = local.environments
  role       = aws_iam_role.deploy[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

data "aws_iam_policy_document" "deploy_extra" {
  for_each = local.environments

  statement {
    sid = "ManageOwnRolesOnly"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:PutRolePolicy",
      "iam:GetRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:ListInstanceProfilesForRole",
      "iam:PassRole",
    ]
    resources = ["arn:aws:iam::${local.account_id}:role/deploytrack-${each.key}-*"]
  }

  statement {
    sid       = "ServiceLinkedRoles"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["arn:aws:iam::${local.account_id}:role/aws-service-role/*"]
  }

  statement {
    sid       = "StateObjects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.state.arn}/deploytrack/${each.key}/*"]
  }

  statement {
    sid       = "StateBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
  }
}

resource "aws_iam_role_policy" "deploy_extra" {
  for_each = local.environments
  name     = "iam-and-state"
  role     = aws_iam_role.deploy[each.key].id
  policy   = data.aws_iam_policy_document.deploy_extra[each.key].json
}
