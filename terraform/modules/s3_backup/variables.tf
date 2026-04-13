variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "enable_replication" {
  description = "Enable S3 cross-region replication to DR bucket"
  type        = bool
  default     = false
}

variable "replication_destination_bucket_arn" {
  description = "ARN of the DR destination S3 bucket. Required when enable_replication = true."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
