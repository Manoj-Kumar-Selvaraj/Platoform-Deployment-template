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

    dynamic "copy_action" {
      for_each = var.dr_vault_arn != "" ? [1] : []
      content {
        destination_vault_arn = var.dr_vault_arn
        lifecycle {
          delete_after = var.dr_retention_days
        }
      }
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
# Moved from aws_backup_selection.efs to .platform to include RDS
moved {
  from = aws_backup_selection.efs
  to   = aws_backup_selection.platform
}

resource "aws_backup_selection" "platform" {
  name         = "${var.project_name}-platform-selection"
  iam_role_arn = aws_iam_role.backup.arn
  plan_id      = aws_backup_plan.efs_daily.id

  resources = concat(var.efs_arns, var.rds_arns)
}
