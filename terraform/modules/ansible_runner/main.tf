# -----------------------------------------------------
# AMI Lookup (Amazon Linux 2023)
# -----------------------------------------------------
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# -----------------------------------------------------
# Ansible Runner Security Group
# -----------------------------------------------------
resource "aws_security_group" "ansible_runner" {
  name_prefix = "${var.project_name}-ansible-runner-"
  vpc_id      = var.vpc_id
  description = "Ansible runner - egress only, SSM managed"

  tags = merge(var.tags, {
    Name = "${var.project_name}-ansible-runner-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "ansible_runner_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ansible_runner.id
  description       = "Allow all outbound"
}

# -----------------------------------------------------
# IAM Role for Ansible Runner
# -----------------------------------------------------
resource "aws_iam_role" "ansible_runner" {
  name = "${var.project_name}-ansible-runner"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ansible_ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.ansible_runner.name
}

resource "aws_iam_role_policy_attachment" "ansible_ecr_read" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.ansible_runner.name
}

resource "aws_iam_role_policy_attachment" "ansible_s3_read" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  role       = aws_iam_role.ansible_runner.name
}

resource "aws_iam_instance_profile" "ansible_runner" {
  name = "${var.project_name}-ansible-runner"
  role = aws_iam_role.ansible_runner.name
}

# -----------------------------------------------------
# Ansible Runner EC2 Instance
# -----------------------------------------------------
resource "aws_instance" "ansible_runner" {
  ami                    = data.aws_ssm_parameter.al2023_ami.value
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  iam_instance_profile   = aws_iam_instance_profile.ansible_runner.name
  vpc_security_group_ids = [aws_security_group.ansible_runner.id]

  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    project_name = var.project_name
  }))

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-ansible-runner"
  })
}
