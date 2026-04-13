# -----------------------------------------------------
# S3 Backup Bucket
# -----------------------------------------------------
resource "aws_s3_bucket" "backup" {
  bucket = "${var.project_name}-${var.environment}-backup-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name = "${var.project_name}-backup"
  })
}

data "aws_caller_identity" "current" {}

# -----------------------------------------------------
# Versioning
# -----------------------------------------------------
resource "aws_s3_bucket_versioning" "backup" {
  bucket = aws_s3_bucket.backup.id

  versioning_configuration {
    status = "Enabled"
  }
}

# -----------------------------------------------------
# Encryption
# -----------------------------------------------------
resource "aws_s3_bucket_server_side_encryption_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# -----------------------------------------------------
# Block Public Access
# -----------------------------------------------------
resource "aws_s3_bucket_public_access_block" "backup" {
  bucket = aws_s3_bucket.backup.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------------------------------
# Lifecycle Rules
# -----------------------------------------------------
resource "aws_s3_bucket_lifecycle_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id

  rule {
    id     = "transition-and-expire"
    status = "Enabled"

    filter {} # Apply to all objects

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
