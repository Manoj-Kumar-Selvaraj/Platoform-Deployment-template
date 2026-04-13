variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "efs_arns" {
  description = "List of EFS ARNs to back up"
  type        = list(string)
}

variable "rds_arns" {
  description = "List of RDS instance ARNs to include in backup plan"
  type        = list(string)
  default     = []
}

variable "retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 35
}

variable "dr_vault_arn" {
  description = "ARN of DR backup vault in secondary region. Empty string disables cross-region copy."
  type        = string
  default     = ""
}

variable "dr_retention_days" {
  description = "Days to retain recovery points in the DR vault"
  type        = number
  default     = 14
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
