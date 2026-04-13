output "instance_id" {
  description = "Ansible runner EC2 instance ID"
  value       = aws_instance.ansible_runner.id
}

output "private_ip" {
  description = "Ansible runner private IP"
  value       = aws_instance.ansible_runner.private_ip
}

output "iam_role_arn" {
  description = "Ansible runner IAM role ARN"
  value       = aws_iam_role.ansible_runner.arn
}
