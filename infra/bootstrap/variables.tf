variable "region" {
  type    = string
  default = "us-east-1"
}

variable "github_repository" {
  description = "owner/repo allowed to assume the CI roles, for example octocat/aws-devops-delivery-platform."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must look like owner/repo."
  }
}

variable "state_bucket_name" {
  description = "Override the state bucket name. Defaults to deploytrack-tfstate-<account id>."
  type        = string
  default     = null
}
