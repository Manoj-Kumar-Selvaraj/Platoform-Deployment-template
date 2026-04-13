locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

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

  project_name     = var.project_name
  repository_names = var.ecr_repository_names
  tags             = local.common_tags
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

  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}

# --- AWS Backup ---
module "backup" {
  source = "../../modules/backup"

  project_name   = var.project_name
  efs_arns       = [module.efs.efs_arn]
  retention_days = var.backup_retention_days
  tags           = local.common_tags
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
