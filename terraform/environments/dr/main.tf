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

module "iam" {
  source = "../../modules/iam"

  cluster_name      = var.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  tags              = local.common_tags
}

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

module "efs" {
  source = "../../modules/efs"

  project_name         = var.project_name
  vpc_id               = module.network.vpc_id
  private_subnet_ids   = module.network.private_subnet_ids
  private_subnet_cidrs = module.network.private_subnet_cidrs
  tags                 = local.common_tags
}

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

module "route53_acm" {
  source = "../../modules/route53_acm"

  domain_name      = var.domain_name
  zone_id_override = var.route53_zone_id
  project_name     = var.project_name
  tags             = local.common_tags
}

module "alb_prereqs" {
  source = "../../modules/alb-prereqs"

  project_name = var.project_name
  vpc_id       = module.network.vpc_id
  tags         = local.common_tags
}

module "ecr" {
  source = "../../modules/ecr"

  project_name          = var.project_name
  repository_names      = var.ecr_repository_names
  enable_dr_replication = false  # No DR-of-DR from secondary region
  dr_region             = var.dr_region
  tags                  = local.common_tags
}

module "codeartifact" {
  source = "../../modules/codeartifact"

  enabled      = var.enable_codeartifact
  project_name = var.project_name
  domain_name  = var.codeartifact_domain_name
  tags         = local.common_tags
}

# S3 backup bucket — Velero writes here; this bucket is the REPLICA from us-east-1
# During DR, Velero reads from this bucket to restore namespaces
module "s3_backup" {
  source = "../../modules/s3_backup"

  project_name                       = var.project_name
  environment                        = var.environment
  enable_replication                 = false  # DR bucket doesn't replicate further
  replication_destination_bucket_arn = ""
  tags                               = local.common_tags
}

module "backup" {
  source = "../../modules/backup"

  project_name           = var.project_name
  efs_arns               = [module.efs.efs_arn]
  rds_arns               = [module.rds_postgres.db_instance_arn]
  retention_days         = var.backup_retention_days
  dr_vault_arn           = ""   # No DR-of-DR
  dr_retention_days      = 14
  trigger_adhoc_backup   = var.trigger_adhoc_backup
  aws_region             = var.aws_region
  tags                   = local.common_tags
}

module "ansible_runner" {
  source = "../../modules/ansible_runner"

  project_name  = var.project_name
  vpc_id        = module.network.vpc_id
  subnet_id     = module.network.private_subnet_ids[0]
  instance_type = var.ansible_runner_instance_type
  tags          = local.common_tags
}

# ==============================================
# DR Restore — RDS Point-in-Time Recovery
# Gated on var.enable_dr_restore = true
# ==============================================

# Auto-discover the latest replicated backup in this region
data "aws_db_instance_automated_backups" "replicated" {
  count = var.enable_dr_restore ? 1 : 0

  db_instance_identifier = "${var.project_name}-sonarqube"

  filter {
    name   = "status"
    values = ["replicating", "retained"]
  }
}

locals {
  # Use explicit override if provided, otherwise pick the latest replicated backup
  dr_rds_backup_arn = (
    var.dr_rds_backup_arn != ""
    ? var.dr_rds_backup_arn
    : try(data.aws_db_instance_automated_backups.replicated[0].instance_automated_backups_arns[0], "")
  )
}

resource "aws_db_instance" "dr_restored" {
  count = var.enable_dr_restore ? 1 : 0

  identifier     = "${var.project_name}-sonarqube-restored"
  instance_class = var.rds_instance_class

  restore_to_point_in_time {
    source_db_instance_automated_backups_arn = local.dr_rds_backup_arn
    use_latest_restorable_time               = true
  }

  db_subnet_group_name   = module.rds_postgres.db_subnet_group_name
  parameter_group_name   = module.rds_postgres.parameter_group_name
  vpc_security_group_ids = [module.rds_postgres.security_group_id]

  publicly_accessible = false
  multi_az            = false
  storage_encrypted   = true

  # Easy teardown when flag is cleared
  deletion_protection = false
  skip_final_snapshot = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-sonarqube-restored"
    Role = "dr-restore"
  })

  lifecycle {
    ignore_changes = [restore_to_point_in_time]
  }

  precondition {
    condition     = local.dr_rds_backup_arn != ""
    error_message = "No replicated backup found and dr_rds_backup_arn not set. Ensure backup replication from primary region is active."
  }
}
