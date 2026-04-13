# ==============================================
# Network
# ==============================================
output "vpc_id" {
  description = "VPC ID"
  value       = module.network.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.network.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.network.public_subnet_ids
}

# ==============================================
# EKS
# ==============================================
output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_oidc_provider_arn" {
  description = "EKS OIDC provider ARN"
  value       = module.eks.oidc_provider_arn
}

output "kubeconfig_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}

# ==============================================
# EFS
# ==============================================
output "efs_id" {
  description = "EFS file system ID"
  value       = module.efs.efs_id
}

# ==============================================
# RDS
# ==============================================
output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = module.rds_postgres.endpoint
}

# ==============================================
# Route53 / ACM
# ==============================================
output "acm_certificate_arn" {
  description = "ACM certificate ARN"
  value       = module.route53_acm.certificate_arn
}

# ==============================================
# ECR
# ==============================================
output "ecr_repository_urls" {
  description = "ECR repository URLs"
  value       = module.ecr.repository_urls
}

# ==============================================
# Ansible Runner
# ==============================================
output "ansible_runner_instance_id" {
  description = "Ansible runner instance ID"
  value       = module.ansible_runner.instance_id
}

# ==============================================
# Platform URLs
# ==============================================
output "jenkins_url" {
  description = "Jenkins URL"
  value       = "https://jenkins.${var.domain_name}"
}

output "sonarqube_url" {
  description = "SonarQube URL"
  value       = "https://sonar.${var.domain_name}"
}

output "sample_app_url" {
  description = "Sample App URL"
  value       = "https://app.${var.domain_name}"
}

# ==============================================
# S3 / Backup
# ==============================================
output "backup_bucket_name" {
  description = "S3 backup bucket name"
  value       = module.s3_backup.bucket_name
}

# ==============================================
# First-Deploy Instructions
# ==============================================
output "next_steps" {
  description = "Post-deploy instructions"
  value       = <<-EOT
    Platform provisioned! Next steps:

    1. Configure kubectl:
       ${format("aws eks update-kubeconfig --name %s --region %s", module.eks.cluster_name, var.aws_region)}

    2. Wait 3-5 min for DNS propagation, then access:
       Jenkins:   https://jenkins.${var.domain_name}
       SonarQube: https://sonar.${var.domain_name}

    3. Generate SonarQube token:
       - Log into SonarQube (admin / admin — change password!)
       - My Account → Security → Generate Token
       - Set 'sonarqube_token' in TFC and re-apply

    4. Push sample app to ECR:
       ${format("aws ecr get-login-password --region %s | docker login --username AWS --password-stdin %s", var.aws_region, split("/", module.ecr.repository_urls["sample-app"])[0])}
       cd kubernetes/apps/sample-app/src
       docker build -t ${module.ecr.repository_urls["sample-app"]}:v1 .
       docker push ${module.ecr.repository_urls["sample-app"]}:v1

    5. Set deploy_sample_app=true and sample_app_image_tag=v1 in TFC, re-apply.
  EOT
}
