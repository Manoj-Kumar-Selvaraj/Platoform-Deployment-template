variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for node groups"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for EKS cluster networking"
  type        = list(string)
}

variable "cluster_role_arn" {
  description = "IAM role ARN for EKS cluster"
  type        = string
}

variable "node_role_arn" {
  description = "IAM role ARN for EKS node groups"
  type        = string
}

variable "public_access" {
  description = "Enable public access to EKS API"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDRs for public API access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# platform-control node group
variable "platform_control_instance_types" {
  description = "Instance types for platform-control node group"
  type        = list(string)
  default     = ["t3.large"]
}

variable "platform_control_desired" {
  type    = number
  default = 2
}

variable "platform_control_min" {
  type    = number
  default = 2
}

variable "platform_control_max" {
  type    = number
  default = 3
}

# platform-exec node group
variable "platform_exec_instance_types" {
  description = "Instance types for platform-exec node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "platform_exec_desired" {
  type    = number
  default = 1
}

variable "platform_exec_min" {
  type    = number
  default = 1
}

variable "platform_exec_max" {
  type    = number
  default = 5
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
