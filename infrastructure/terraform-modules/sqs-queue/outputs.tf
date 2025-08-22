output "queue_name" {
  description = "Name of the created SQS queue"
  value       = aws_sqs_queue.queue.name
}

output "queue_arn" {
  description = "ARN of the created SQS queue"
  value       = aws_sqs_queue.queue.arn
}

output "queue_url" {
  description = "URL of the created SQS queue"
  value       = aws_sqs_queue.queue.url
}

output "dlq_arn" {
  description = "ARN of the dead letter queue"
  value       = var.enable_dlq ? aws_sqs_queue.dlq[0].arn : null
}

output "dlq_url" {
  description = "URL of the dead letter queue"
  value       = var.enable_dlq ? aws_sqs_queue.dlq[0].url : null
}

output "access_policy_arn" {
  description = "ARN of the IAM policy for SQS access"
  value       = aws_iam_policy.sqs_access_policy.arn
}
