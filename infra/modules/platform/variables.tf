variable "project" {
  type    = string
  default = "deploytrack"
}

variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "region" {
  type = string
}

variable "ecr_repository_name" {
  description = "Shared ECR repository created by infra/bootstrap. One image is promoted through every environment."
  type        = string
  default     = "deploytrack"
}

variable "image_tag" {
  description = "Immutable image tag, the git commit SHA. Set by the pipeline."
  type        = string
}

variable "app_version" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "az_count" {
  type = number
}

variable "single_nat_gateway" {
  type = bool
}

variable "cpu" {
  type = number
}

variable "memory" {
  type = number
}

variable "min_count" {
  type = number
}

variable "max_count" {
  type = number
}

variable "use_fargate_spot" {
  type = bool
}

variable "log_retention_days" {
  type = number
}

variable "deletion_protection" {
  type = bool
}

variable "latency_p95_threshold_seconds" {
  type    = number
  default = 0.5
}

variable "certificate_arn" {
  type    = string
  default = null
}

variable "alarm_email" {
  type    = string
  default = null
}
