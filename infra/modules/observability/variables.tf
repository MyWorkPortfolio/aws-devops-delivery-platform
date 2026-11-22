variable "name" {
  type = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "alarm_email" {
  description = "Optional email for alarm notifications. Confirm the SNS subscription after first apply."
  type        = string
  default     = null
}

variable "alb_arn_suffix" {
  type = string
}

variable "target_group_arn_suffix" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "service_name" {
  type = string
}

variable "dynamodb_table_name" {
  type = string
}

variable "log_group_name" {
  type = string
}

variable "error_rate_threshold_percent" {
  type    = number
  default = 2
}

variable "latency_p95_threshold_seconds" {
  type    = number
  default = 0.5
}

variable "app_error_threshold" {
  description = "ERROR log lines tolerated per 5 minutes before alerting."
  type        = number
  default     = 5
}
