variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "repository_names" {
  description = "List of ECR repository names"
  type        = list(string)
  default     = ["sample-app"]
}

variable "max_tagged_images" {
  description = "Maximum number of tagged images to retain"
  type        = number
  default     = 30
}

variable "untagged_expiry_days" {
  description = "Days before untagged images expire"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
