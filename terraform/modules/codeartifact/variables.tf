variable "enabled" {
  description = "Enable CodeArtifact provisioning"
  type        = bool
  default     = true
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "domain_name" {
  description = "CodeArtifact domain name"
  type        = string
}

variable "external_connection" {
  description = "External connection for upstream repo (e.g., public:npmjs, public:pypi, public:maven-central)"
  type        = string
  default     = "public:npmjs"
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
