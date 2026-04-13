# -----------------------------------------------------
# EKS Cluster
# -----------------------------------------------------
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.kubernetes_version
  role_arn = var.cluster_role_arn

  vpc_config {
    subnet_ids              = concat(var.private_subnet_ids, var.public_subnet_ids)
    endpoint_private_access = true
    endpoint_public_access  = var.public_access
    public_access_cidrs     = var.public_access_cidrs
    security_group_ids      = [aws_security_group.cluster.id]
  }

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  tags = merge(var.tags, {
    Name = var.cluster_name
  })

  depends_on = [var.cluster_role_arn]
}

# -----------------------------------------------------
# Cluster Security Group
# -----------------------------------------------------
resource "aws_security_group" "cluster" {
  name_prefix = "${var.cluster_name}-cluster-"
  vpc_id      = var.vpc_id
  description = "EKS cluster security group"

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-cluster-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "cluster_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.cluster.id
  description       = "Allow all outbound traffic"
}

# -----------------------------------------------------
# OIDC Provider for IRSA
# -----------------------------------------------------
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = var.tags
}

# -----------------------------------------------------
# EKS Addons
# -----------------------------------------------------
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.platform_control,
    aws_eks_node_group.platform_exec
  ]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

# -----------------------------------------------------
# Node Group: platform-control
# -----------------------------------------------------
resource "aws_eks_node_group" "platform_control" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-platform-control"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.private_subnet_ids

  instance_types = var.platform_control_instance_types
  capacity_type  = "ON_DEMAND"

  scaling_config {
    desired_size = var.platform_control_desired
    min_size     = var.platform_control_min
    max_size     = var.platform_control_max
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "platform-control"
  }

  taint {
    key    = "platform-control"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-platform-control"
  })
}

# -----------------------------------------------------
# Node Group: platform-exec
# -----------------------------------------------------
resource "aws_eks_node_group" "platform_exec" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-platform-exec"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.private_subnet_ids

  instance_types = var.platform_exec_instance_types
  capacity_type  = "ON_DEMAND"

  scaling_config {
    desired_size = var.platform_exec_desired
    min_size     = var.platform_exec_min
    max_size     = var.platform_exec_max
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "platform-exec"
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-platform-exec"
  })
}
