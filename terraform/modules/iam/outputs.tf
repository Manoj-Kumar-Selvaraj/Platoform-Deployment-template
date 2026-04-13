output "eks_cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = aws_iam_role.eks_cluster.arn
}

output "eks_node_role_arn" {
  description = "ARN of the EKS node group IAM role"
  value       = aws_iam_role.eks_nodes.arn
}

output "alb_controller_role_arn" {
  description = "ARN of the ALB controller IRSA role"
  value       = aws_iam_role.alb_controller.arn
}

output "efs_csi_role_arn" {
  description = "ARN of the EFS CSI IRSA role"
  value       = aws_iam_role.efs_csi.arn
}

output "external_dns_role_arn" {
  description = "ARN of the ExternalDNS IRSA role"
  value       = aws_iam_role.external_dns.arn
}
