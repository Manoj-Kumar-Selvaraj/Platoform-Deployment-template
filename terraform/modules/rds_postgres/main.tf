# -----------------------------------------------------
# DB Subnet Group
# -----------------------------------------------------
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-rds-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.project_name}-rds-subnet-group"
  })
}

# -----------------------------------------------------
# DB Parameter Group
# -----------------------------------------------------
resource "aws_db_parameter_group" "main" {
  name   = "${var.project_name}-pg15-params"
  family = "postgres15"

  parameter {
    name         = "max_connections"
    value        = "200"
    apply_method = "pending-reboot"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-pg15-params"
  })
}

# -----------------------------------------------------
# RDS Security Group
# -----------------------------------------------------
resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-rds-"
  vpc_id      = var.vpc_id
  description = "Allow PostgreSQL from private subnets"

  tags = merge(var.tags, {
    Name = "${var.project_name}-rds-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "rds_ingress" {
  count = length(var.private_subnet_cidrs)

  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = [var.private_subnet_cidrs[count.index]]
  security_group_id = aws_security_group.rds.id
  description       = "PostgreSQL from private subnet ${count.index}"
}

resource "aws_security_group_rule" "rds_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rds.id
  description       = "Allow all outbound"
}

# -----------------------------------------------------
# RDS PostgreSQL Instance
# -----------------------------------------------------
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-sonarqube"

  engine                = "postgres"
  engine_version        = "15"
  instance_class        = var.instance_class
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.allocated_storage * 2

  db_name  = var.db_name
  username = var.username
  password = var.password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  parameter_group_name   = aws_db_parameter_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible       = false
  multi_az                  = false
  storage_encrypted         = true
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = !var.deletion_protection
  final_snapshot_identifier = var.deletion_protection ? "${var.project_name}-sonarqube-final" : null

  backup_retention_period = var.backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  tags = merge(var.tags, {
    Name = "${var.project_name}-sonarqube-db"
  })
}
