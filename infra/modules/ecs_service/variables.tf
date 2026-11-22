variable "name" {
  description = "Name for the cluster, service, load balancer and roles."
  type        = string
}

variable "environment" {
  description = "dev, staging or prod. Passed to the container."
  type        = string
}

variable "region" {
  description = "AWS region for log configuration and the app's SDK client."
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  description = "Subnets for the internet facing load balancer."
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Subnets for the tasks. No public IPs are assigned."
  type        = list(string)
}

variable "container_image" {
  description = "Full image reference, pinned to an immutable tag."
  type        = string
}

variable "app_version" {
  description = "Version string the app reports on / and in app_info metrics."
  type        = string
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "cpu" {
  description = "Fargate task CPU units."
  type        = number
  default     = 256
}

variable "memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Initial task count. Autoscaling takes over after the first apply."
  type        = number
  default     = 1
}

variable "min_count" {
  type    = number
  default = 1
}

variable "max_count" {
  type    = number
  default = 2

  validation {
    condition     = var.max_count >= 1
    error_message = "max_count must be at least 1."
  }
}

variable "cpu_target_percent" {
  type    = number
  default = 60
}

variable "requests_per_target" {
  description = "Target ALB requests per task per minute."
  type        = number
  default     = 500
}

variable "use_fargate_spot" {
  description = "Run on Fargate Spot for up to 70% savings. Fine for dev and staging, not prod."
  type        = bool
  default     = false
}

variable "dynamodb_table_name" {
  type = string
}

variable "dynamodb_table_arn" {
  type = string
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "log_level" {
  type    = string
  default = "INFO"
}

variable "certificate_arn" {
  description = "ACM certificate. When set, HTTP redirects to HTTPS with TLS 1.3."
  type        = string
  default     = null
}

variable "allowed_ingress_cidrs" {
  description = "Who may reach the load balancer."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_deletion_protection" {
  type    = bool
  default = false
}
