variable "domain_name" {
  description = "Root domain name"
  type        = string
}

variable "zone_id_override" {
  description = "Override Route53 zone ID (leave empty for auto-lookup)"
  type        = string
  default     = ""
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
