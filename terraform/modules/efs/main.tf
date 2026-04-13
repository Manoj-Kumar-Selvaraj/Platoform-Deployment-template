# -----------------------------------------------------
# EFS File System
# -----------------------------------------------------
resource "aws_efs_file_system" "main" {
  creation_token = "${var.project_name}-efs"
  encrypted      = true

  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  tags = merge(var.tags, {
    Name = "${var.project_name}-efs"
  })

  lifecycle {
    prevent_destroy = true
  }
}

# -----------------------------------------------------
# EFS Security Group
# -----------------------------------------------------
resource "aws_security_group" "efs" {
  name_prefix = "${var.project_name}-efs-"
  vpc_id      = var.vpc_id
  description = "Allow NFS traffic from private subnets"

  tags = merge(var.tags, {
    Name = "${var.project_name}-efs-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "efs_ingress" {
  count = length(var.private_subnet_cidrs)

  type              = "ingress"
  from_port         = 2049
  to_port           = 2049
  protocol          = "tcp"
  cidr_blocks       = [var.private_subnet_cidrs[count.index]]
  security_group_id = aws_security_group.efs.id
  description       = "NFS from private subnet ${count.index}"
}

resource "aws_security_group_rule" "efs_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.efs.id
  description       = "Allow all outbound"
}

# -----------------------------------------------------
# EFS Mount Targets (one per private subnet)
# -----------------------------------------------------
resource "aws_efs_mount_target" "main" {
  count = length(var.private_subnet_ids)

  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = var.private_subnet_ids[count.index]
  security_groups = [aws_security_group.efs.id]
}

# -----------------------------------------------------
# EFS Access Point for Jenkins
# -----------------------------------------------------
resource "aws_efs_access_point" "jenkins" {
  file_system_id = aws_efs_file_system.main.id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/jenkins-home"

    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "755"
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-jenkins-ap"
  })
}
