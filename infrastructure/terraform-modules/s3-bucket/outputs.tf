output "bucket_name" {
  description = "Name of the created S3 bucket"
  value       = aws_s3_bucket.bucket.bucket
}

output "bucket_arn" {
  description = "ARN of the created S3 bucket"
  value       = aws_s3_bucket.bucket.arn
}

output "bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = aws_s3_bucket.bucket.bucket_domain_name
}

output "access_policy_arn" {
  description = "ARN of the IAM policy for S3 access"
  value       = aws_iam_policy.s3_access_policy.arn
}
