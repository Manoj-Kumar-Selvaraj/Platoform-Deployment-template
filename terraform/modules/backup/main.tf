# -----------------------------------------------------
# AWS Backup Vault
# -----------------------------------------------------
resource "aws_backup_vault" "main" {
  name = "${var.project_name}-backup-vault"
  tags = var.tags

  lifecycle {
    prevent_destroy = true
  }
}

# -----------------------------------------------------
# AWS Backup Plan
# -----------------------------------------------------
resource "aws_backup_plan" "efs_daily" {
  name = "${var.project_name}-efs-daily"

  rule {
    rule_name         = "daily-efs-backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 3 * * ? *)"

    lifecycle {
      delete_after = var.retention_days
    }

    recovery_point_tags = var.tags
  }

  tags = var.tags
}

# -----------------------------------------------------
# Backup IAM Role
# -----------------------------------------------------
resource "aws_iam_role" "backup" {
  name = "${var.project_name}-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "backup.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "backup" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.backup.name
}

resource "aws_iam_role_policy_attachment" "restore" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
  role       = aws_iam_role.backup.name
}

# -----------------------------------------------------
# Backup Selection (EFS)
# -----------------------------------------------------
resource "aws_backup_selection" "efs" {
  name         = "${var.project_name}-efs-selection"
  iam_role_arn = aws_iam_role.backup.arn
  plan_id      = aws_backup_plan.efs_daily.id

  resources = var.efs_arns
}
