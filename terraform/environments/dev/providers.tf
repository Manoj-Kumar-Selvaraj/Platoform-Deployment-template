provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# -----------------------------------------------------
# EKS auth — token generated via AWS SDK (works in TFC).
# References module output so it's deferred until EKS exists.
# -----------------------------------------------------
data "aws_eks_cluster_auth" "main" {
  name = module.eks.cluster_name
}

# -----------------------------------------------------
# Kubernetes provider
# -----------------------------------------------------
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.main.token
}

# -----------------------------------------------------
# Helm provider
# -----------------------------------------------------
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}
