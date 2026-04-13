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
    DR Recovery Steps:

    1. Configure kubectl:
       ${format("aws eks update-kubeconfig --name %s --region %s", module.eks.cluster_name, var.aws_region)}

    2. Restore RDS from replicated backups:
       aws rds describe-db-instance-automated-backups \
         --region ${var.aws_region} \
         --query 'DBInstanceAutomatedBackups[?DBInstanceIdentifier==`platform-mvp-sonarqube`].DBInstanceAutomatedBackupsArn'

       aws rds restore-db-instance-to-point-in-time \
         --region ${var.aws_region} \
         --source-db-instance-automated-backups-arn <ARN> \
         --target-db-instance-identifier platform-mvp-sonarqube-restored

    3. Set TFC variable: rds_endpoint_override = <restored endpoint>
       Re-apply: terraform apply -target=helm_release.sonarqube

    4. Velero restore (reads from replicated S3 bucket):
       velero backup-location create dr-replica \
         --provider aws \
         --bucket ${module.s3_backup.bucket_name} \
         --prefix velero \
         --config region=${var.aws_region}

       velero restore create dr-restore \
         --from-backup daily-platform-backup-<LATEST> \
         --storage-location dr-replica \
         --include-namespaces jenkins,sonarqube,artifactory

    5. Verify:
       curl https://jenkins.${var.domain_name}/login
       curl https://sonar.${var.domain_name}/api/system/status
  EOT
}
