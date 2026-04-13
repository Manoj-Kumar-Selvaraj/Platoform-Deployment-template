locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

data "aws_caller_identity" "current" {}

# ==============================================
# Phase 1: Foundations
# ==============================================

# --- Network ---
module "network" {
  source = "../../modules/network"

  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  cluster_name         = var.cluster_name
  project_name         = var.project_name
  enable_nat_per_az    = var.enable_nat_gateway_per_az
  tags                 = local.common_tags
}

# --- IAM (base roles, no IRSA yet) ---
module "iam" {
  source = "../../modules/iam"

  cluster_name      = var.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  tags              = local.common_tags
}

# --- EKS ---
module "eks" {
  source = "../../modules/eks"

  cluster_name        = var.cluster_name
  kubernetes_version  = var.kubernetes_version
  vpc_id              = module.network.vpc_id
  private_subnet_ids  = module.network.private_subnet_ids
  public_subnet_ids   = module.network.public_subnet_ids
  cluster_role_arn    = module.iam.eks_cluster_role_arn
  node_role_arn       = module.iam.eks_node_role_arn
  public_access       = var.eks_public_access
  public_access_cidrs = var.eks_public_access_cidrs

  platform_control_instance_types = var.platform_control_instance_types
  platform_control_desired        = var.platform_control_desired
  platform_control_min            = var.platform_control_min
  platform_control_max            = var.platform_control_max

  platform_exec_instance_types = var.platform_exec_instance_types
  platform_exec_desired        = var.platform_exec_desired
  platform_exec_min            = var.platform_exec_min
  platform_exec_max            = var.platform_exec_max

  tags = local.common_tags
}

# ==============================================
# Phase 2: Core Controllers
# ==============================================

# --- EFS ---
module "efs" {
  source = "../../modules/efs"

  project_name         = var.project_name
  vpc_id               = module.network.vpc_id
  private_subnet_ids   = module.network.private_subnet_ids
  private_subnet_cidrs = module.network.private_subnet_cidrs
  tags                 = local.common_tags
}

# --- RDS PostgreSQL ---
module "rds_postgres" {
  source = "../../modules/rds_postgres"

  project_name            = var.project_name
  vpc_id                  = module.network.vpc_id
  private_subnet_ids      = module.network.private_subnet_ids
  private_subnet_cidrs    = module.network.private_subnet_cidrs
  db_name                 = var.rds_db_name
  username                = var.rds_username
  password                = var.rds_password
  instance_class          = var.rds_instance_class
  allocated_storage       = var.rds_allocated_storage
  deletion_protection     = var.rds_deletion_protection
  backup_retention_period = var.rds_backup_retention_period
  tags                    = local.common_tags
}

# --- Route53 + ACM ---
module "route53_acm" {
  source = "../../modules/route53_acm"

  domain_name      = var.domain_name
  zone_id_override = var.route53_zone_id
  project_name     = var.project_name
  tags             = local.common_tags
}

# --- ALB Prerequisites ---
module "alb_prereqs" {
  source = "../../modules/alb-prereqs"

  project_name = var.project_name
  vpc_id       = module.network.vpc_id
  tags         = local.common_tags
}

# --- ECR ---
module "ecr" {
  source = "../../modules/ecr"

  project_name          = var.project_name
  repository_names      = var.ecr_repository_names
  enable_dr_replication = var.enable_dr
  dr_region             = var.dr_region
  tags                  = local.common_tags
}

# --- CodeArtifact (feature-flagged) ---
module "codeartifact" {
  source = "../../modules/codeartifact"

  enabled      = var.enable_codeartifact
  project_name = var.project_name
  domain_name  = var.codeartifact_domain_name
  tags         = local.common_tags
}

# --- S3 Backup ---
module "s3_backup" {
  source = "../../modules/s3_backup"

  project_name                       = var.project_name
  environment                        = var.environment
  enable_replication                 = var.enable_dr
  replication_destination_bucket_arn = var.enable_dr ? aws_s3_bucket.backup_dr[0].arn : ""
  tags                               = local.common_tags
}

# --- AWS Backup ---
module "backup" {
  source = "../../modules/backup"

  project_name           = var.project_name
  efs_arns               = [module.efs.efs_arn]
  rds_arns               = [module.rds_postgres.db_instance_arn]
  retention_days         = var.backup_retention_days
  dr_vault_arn           = var.enable_dr ? aws_backup_vault.dr[0].arn : ""
  dr_retention_days      = 14
  trigger_adhoc_backup   = var.trigger_adhoc_backup
  aws_region             = var.aws_region
  tags                   = local.common_tags
}

# --- Ansible Runner ---
module "ansible_runner" {
  source = "../../modules/ansible_runner"

  project_name  = var.project_name
  vpc_id        = module.network.vpc_id
  subnet_id     = module.network.private_subnet_ids[0]
  instance_type = var.ansible_runner_instance_type
  tags          = local.common_tags
}

# ==============================================
# Disaster Recovery Resources (us-west-2)
# All gated on var.enable_dr = true
# ==============================================

# DR Backup Vault
resource "aws_backup_vault" "dr" {
  count    = var.enable_dr ? 1 : 0
  provider = aws.dr
  name     = "${var.project_name}-backup-vault-dr"
  tags     = local.common_tags

  lifecycle {
    prevent_destroy = true
  }
}

# DR S3 Bucket (replication destination for backup bucket)
resource "aws_s3_bucket" "backup_dr" {
  count    = var.enable_dr ? 1 : 0
  provider = aws.dr
  bucket   = "${var.project_name}-${var.environment}-backup-dr-${data.aws_caller_identity.current.account_id}"
  tags     = merge(local.common_tags, { Name = "${var.project_name}-backup-dr" })
}

resource "aws_s3_bucket_versioning" "backup_dr" {
  count    = var.enable_dr ? 1 : 0
  provider = aws.dr
  bucket   = aws_s3_bucket.backup_dr[0].id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backup_dr" {
  count    = var.enable_dr ? 1 : 0
  provider = aws.dr
  bucket   = aws_s3_bucket.backup_dr[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "backup_dr" {
  count    = var.enable_dr ? 1 : 0
  provider = aws.dr
  bucket   = aws_s3_bucket.backup_dr[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "backup_dr" {
  count    = var.enable_dr ? 1 : 0
  provider = aws.dr
  bucket   = aws_s3_bucket.backup_dr[0].id

  rule {
    id     = "transition-and-expire"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# RDS Automated Backup Replication to us-west-2
# Provides continuous PITR-capable backups in the DR region
resource "aws_db_instance_automated_backups_replication" "sonarqube_dr" {
  count                  = var.enable_dr ? 1 : 0
  provider               = aws.dr
  source_db_instance_arn = module.rds_postgres.db_instance_arn
  retention_period       = 7
}
