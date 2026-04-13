output "domain_name" {
  description = "CodeArtifact domain name"
  value       = var.enabled ? aws_codeartifact_domain.main[0].domain : ""
}

output "internal_repository_name" {
  description = "Internal repository name"
  value       = var.enabled ? aws_codeartifact_repository.internal[0].repository : ""
}

output "domain_owner" {
  description = "CodeArtifact domain owner (AWS account ID)"
  value       = var.enabled ? aws_codeartifact_domain.main[0].owner : ""
}
