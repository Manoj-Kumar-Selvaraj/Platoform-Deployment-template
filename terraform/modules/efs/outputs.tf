output "efs_id" {
  description = "EFS file system ID"
  value       = aws_efs_file_system.main.id
}

output "efs_arn" {
  description = "EFS file system ARN"
  value       = aws_efs_file_system.main.arn
}

output "jenkins_access_point_id" {
  description = "EFS access point ID for Jenkins"
  value       = aws_efs_access_point.jenkins.id
}

output "efs_security_group_id" {
  description = "Security group ID for EFS"
  value       = aws_security_group.efs.id
}
