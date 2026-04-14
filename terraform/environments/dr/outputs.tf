# DR workspace outputs — identical to dev

output "vpc_id" {
  description = "VPC ID"
  value       = module.network.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.network.private_subnet_ids
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "kubeconfig_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}

output "efs_id" {
  description = "EFS file system ID"
  value       = module.efs.efs_id
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = module.rds_postgres.endpoint
}

output "dr_restored_rds_endpoint" {
  description = "DR-restored RDS endpoint (only available when enable_dr_restore = true)"
  value       = var.enable_dr_restore && length(aws_db_instance.dr_restored) > 0 ? aws_db_instance.dr_restored[0].endpoint : ""
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN"
  value       = module.route53_acm.certificate_arn
}

output "backup_bucket_name" {
  description = "S3 backup bucket name"
  value       = module.s3_backup.bucket_name
}

output "jenkins_url" {
  description = "Jenkins URL"
  value       = "https://jenkins.${var.domain_name}"
}

output "sonarqube_url" {
  description = "SonarQube URL"
  value       = "https://sonar.${var.domain_name}"
}

output "dr_recovery_steps" {
  description = "DR recovery instructions"
  value       = <<-EOT
    DR Recovery Steps (Automated):

    1. Get the replicated backup ARN:
       aws rds describe-db-instance-automated-backups \
         --region ${var.aws_region} \
         --query 'DBInstanceAutomatedBackups[].DBInstanceAutomatedBackupsArn' --output text

    2. Set TFC variables:
       enable_dr_restore = true
       dr_rds_backup_arn = "<ARN from step 1>"

    3. Apply — RDS restores + Velero restore job runs automatically:
       terraform apply

    4. Verify:
       curl https://sonar.${var.domain_name}/api/system/status
       curl https://jenkins.${var.domain_name}/login
       kubectl get jobs -n velero

    5. After verification, clean up restored resources:
       enable_dr_restore = false
       dr_rds_backup_arn = ""
       terraform apply

    Manual override (legacy):
       Set rds_endpoint_override to a manually restored RDS address.
  EOT
}
