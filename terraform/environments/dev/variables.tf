# -----------------------------------------------------
# General
# -----------------------------------------------------
variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "platform-mvp"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

# -----------------------------------------------------
# Domain
# -----------------------------------------------------
variable "domain_name" {
  description = "Root domain name for the platform"
  type        = string
}

variable "route53_zone_id" {
  description = "Override Route53 hosted zone ID. If empty, zone is looked up by domain_name."
  type        = string
  default     = ""
}

# -----------------------------------------------------
# Networking
# -----------------------------------------------------
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.10.1.0/24", "10.10.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.10.11.0/24", "10.10.12.0/24"]
}

variable "availability_zones" {
  description = "Availability zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "enable_nat_gateway_per_az" {
  description = "Create one NAT Gateway per AZ (true) or single NAT Gateway (false)"
  type        = bool
  default     = false
}

# -----------------------------------------------------
# EKS
# -----------------------------------------------------
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "platform-mvp-dev"
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.34"
}

variable "eks_public_access" {
  description = "Enable public access to EKS API endpoint"
  type        = bool
  default     = true
}

variable "eks_public_access_cidrs" {
  description = "CIDR blocks allowed to access EKS public endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Node group: platform-control
variable "platform_control_instance_types" {
  description = "Instance types for platform-control node group"
  type        = list(string)
  default     = ["t3.large"]
}

variable "platform_control_desired" {
  description = "Desired size for platform-control node group"
  type        = number
  default     = 2
}

variable "platform_control_min" {
  description = "Min size for platform-control node group"
  type        = number
  default     = 2
}

variable "platform_control_max" {
  description = "Max size for platform-control node group"
  type        = number
  default     = 3
}

# Node group: platform-exec
variable "platform_exec_instance_types" {
  description = "Instance types for platform-exec node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "platform_exec_desired" {
  description = "Desired size for platform-exec node group"
  type        = number
  default     = 1
}

variable "platform_exec_min" {
  description = "Min size for platform-exec node group"
  type        = number
  default     = 1
}

variable "platform_exec_max" {
  description = "Max size for platform-exec node group"
  type        = number
  default     = 5
}

# -----------------------------------------------------
# RDS (SonarQube)
# -----------------------------------------------------
variable "rds_instance_class" {
  description = "RDS instance class for SonarQube PostgreSQL"
  type        = string
  default     = "db.t3.medium"
}

variable "rds_allocated_storage" {
  description = "Allocated storage in GB for RDS"
  type        = number
  default     = 20
}

variable "rds_db_name" {
  description = "Database name for SonarQube"
  type        = string
  default     = "sonarqube"
}

variable "rds_username" {
  description = "Master username for RDS"
  type        = string
  default     = "sonarqube"
}

variable "rds_password" {
  description = "Master password for RDS (sensitive)"
  type        = string
  sensitive   = true
}

variable "rds_deletion_protection" {
  description = "Enable deletion protection for RDS"
  type        = bool
  default     = true
}

variable "rds_backup_retention_period" {
  description = "Number of days to retain RDS backups"
  type        = number
  default     = 7
}

# -----------------------------------------------------
# ECR
# -----------------------------------------------------
variable "ecr_repository_names" {
  description = "List of ECR repository names to create"
  type        = list(string)
  default     = ["sample-app", "jenkins-agent"]
}

# -----------------------------------------------------
# CodeArtifact
# -----------------------------------------------------
variable "enable_codeartifact" {
  description = "Enable CodeArtifact provisioning"
  type        = bool
  default     = true
}

variable "codeartifact_domain_name" {
  description = "CodeArtifact domain name"
  type        = string
  default     = "platform-mvp"
}

# -----------------------------------------------------
# Ansible Runner
# -----------------------------------------------------
variable "ansible_runner_instance_type" {
  description = "Instance type for Ansible runner"
  type        = string
  default     = "t3.small"
}

# -----------------------------------------------------
# Backup
# -----------------------------------------------------
variable "backup_retention_days" {
  description = "Number of days to retain AWS Backup recovery points"
  type        = number
  default     = 35
}

# -----------------------------------------------------
# Jenkins (set as sensitive TFC variables)
# -----------------------------------------------------
variable "jenkins_admin_user" {
  description = "Jenkins admin username"
  type        = string
  default     = "admin"
}

variable "jenkins_admin_password" {
  description = "Jenkins admin password (sensitive — set in TFC)"
  type        = string
  sensitive   = true
}

# -----------------------------------------------------
# SonarQube Integration
# -----------------------------------------------------
variable "sonarqube_token" {
  description = "SonarQube API token for Jenkins integration. Leave empty on first deploy, set after SonarQube is up."
  type        = string
  sensitive   = true
  default     = ""
}

# -----------------------------------------------------
# Sample App
# -----------------------------------------------------
variable "deploy_sample_app" {
  description = "Deploy sample app Helm chart. Set true after pushing image to ECR."
  type        = bool
  default     = false
}

variable "sample_app_image_tag" {
  description = "Sample app image tag to deploy (must exist in ECR)"
  type        = string
  default     = "latest"
}

# -----------------------------------------------------
# Disaster Recovery
# -----------------------------------------------------
variable "dr_region" {
  description = "Secondary AWS region for disaster recovery replication"
  type        = string
  default     = "us-west-2"
}

variable "enable_dr" {
  description = "Enable cross-region DR: backup copy, S3 CRR, RDS replication, ECR replication. Set true after initial deploy is stable."
  type        = bool
  default     = false
}

variable "enable_velero" {
  description = "Deploy Velero for Kubernetes-level backup of namespaces and PVC data to S3"
  type        = bool
  default     = false
}

variable "rds_endpoint_override" {
  description = "Override RDS endpoint. Used during DR recovery when restoring RDS from a replicated backup in the secondary region."
  type        = string
  default     = ""
}

# ==============================================
# Ad-hoc Backup
# ==============================================
variable "trigger_adhoc_backup" {
  description = "Trigger ad-hoc on-demand backups for all EFS and RDS resources. Set to any non-empty value (e.g., current date YYYY-MM-DD) to run. Clear after backup completes."
  type        = string
  default     = ""
}
