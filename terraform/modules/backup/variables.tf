variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "efs_arns" {
  description = "List of EFS ARNs to back up"
  type        = list(string)
}

variable "retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 35
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
