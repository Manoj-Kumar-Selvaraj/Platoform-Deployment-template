output "bucket_arn" {
  description = "S3 backup bucket ARN"
  value       = aws_s3_bucket.backup.arn
}

output "bucket_name" {
  description = "S3 backup bucket name"
  value       = aws_s3_bucket.backup.id
}

output "bucket_id" {
  description = "S3 backup bucket ID"
  value       = aws_s3_bucket.backup.id
}
