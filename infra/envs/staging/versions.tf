terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Partial config: bucket and region come from -backend-config so no account
  # specific value is committed. S3 native locking, no DynamoDB lock table needed.
  backend "s3" {
    key          = "deploytrack/staging/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "deploytrack"
      Environment = "staging"
      ManagedBy   = "terraform"
      Repository  = var.repository
    }
  }
}
