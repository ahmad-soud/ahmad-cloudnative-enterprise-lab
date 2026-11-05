# --- 1. Dead Letter Queue (DLQ) for Failed Messages ---
resource "aws_sqs_queue" "enterprise_queue_dlq" {
  name                      = "ahmad-enterprise-dlq"
  message_retention_seconds = 1209600 # Retain failed messages for 14 days for investigation
  sqs_managed_sse_enabled   = true    # Enable automated server-side encryption 

  tags = { Name = "Ahmad-Enterprise-DLQ" }
}

# --- 2. Main Application SQS Queue ---
resource "aws_sqs_queue" "enterprise_queue" {
  name                      = "ahmad-enterprise-main-queue"
  delay_seconds             = 0
  max_message_size          = 262144 # Maximum message size of 256 KB
  message_retention_seconds = 345600 # Retain normal messages for 4 days if workers are down
  receive_wait_time_seconds = 20     # Enable Long Polling to optimize request costs 
  sqs_managed_sse_enabled   = true    # Server-side encryption for secure data protection

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.enterprise_queue_dlq.arn
    maxReceiveCount     = 3
  })

  tags = { Name = "Ahmad-Enterprise-Main-Queue" }
}

output "queue_id" { value = aws_sqs_queue.enterprise_queue.id }
output "queue_arn" { value = aws_sqs_queue.enterprise_queue.arn }
