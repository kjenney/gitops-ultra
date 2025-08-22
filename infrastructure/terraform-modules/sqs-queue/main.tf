terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_sqs_queue" "queue" {
  name                       = var.queue_name
  delay_seconds              = var.delay_seconds
  max_message_size           = var.max_message_size
  message_retention_seconds  = var.message_retention_seconds
  visibility_timeout_seconds = var.visibility_timeout_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds

  redrive_policy = var.enable_dlq ? jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[0].arn
    maxReceiveCount     = var.max_receive_count
  }) : null

  tags = merge(var.tags, {
    Name = var.queue_name
  })
}

resource "aws_sqs_queue" "dlq" {
  count = var.enable_dlq ? 1 : 0
  name  = "${var.queue_name}-dlq"

  tags = merge(var.tags, {
    Name = "${var.queue_name}-dlq"
  })
}

# IAM policy for SQS access
resource "aws_iam_policy" "sqs_access_policy" {
  name        = "${var.queue_name}-access-policy"
  description = "Policy for accessing SQS queue ${var.queue_name}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = concat(
          [aws_sqs_queue.queue.arn],
          var.enable_dlq ? [aws_sqs_queue.dlq[0].arn] : []
        )
      }
    ]
  })

  tags = var.tags
}
