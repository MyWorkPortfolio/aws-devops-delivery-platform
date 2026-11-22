variable "name" {
  description = "Table name."
  type        = string
}

variable "deletion_protection" {
  description = "Block table deletion. On in prod so a bad plan cannot drop data."
  type        = bool
  default     = false
}
