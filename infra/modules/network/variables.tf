variable "name" {
  description = "Name prefix for every network resource."
  type        = string
}

variable "region" {
  description = "AWS region, used to build VPC endpoint service names."
  type        = string
}

variable "cidr_block" {
  description = "VPC CIDR. Each environment gets its own non overlapping range so peering stays possible."
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "cidr_block must be a valid IPv4 CIDR."
  }
}

variable "az_count" {
  description = "Number of availability zones to spread subnets across."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3 so the load balancer stays highly available."
  }
}

variable "single_nat_gateway" {
  description = "One shared NAT gateway (cheap, for dev and staging) or one per AZ (resilient, for prod)."
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "Retention for rejected traffic flow logs."
  type        = number
  default     = 30
}
