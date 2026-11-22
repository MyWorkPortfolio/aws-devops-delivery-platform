variable "region" {
  type    = string
  default = "us-east-1"
}

variable "repository" {
  description = "GitHub repository, recorded as a tag on every resource."
  type        = string
  default     = "unknown"
}

variable "image_tag" {
  description = "Git commit SHA of the image to run. Supplied by the pipeline."
  type        = string
}

variable "app_version" {
  type    = string
  default = "0.0.0"
}

variable "certificate_arn" {
  type    = string
  default = null
}

variable "alarm_email" {
  type    = string
  default = null
}
