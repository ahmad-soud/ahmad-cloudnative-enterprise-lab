variable "alb_arn_suffix" { type = string }

variable "telegram_bot_token" {
  type        = string
  description = "Telegram Bot Token for alerting notifications"
  sensitive   = true
}

variable "telegram_chat_id" {
  type        = string
  description = "Telegram Chat ID for alerting notifications"
}

# --- 1. SNS Topic for Enterprise Alerts ---
resource "aws_sns_topic" "alarm_topic" {
  name = "ahmad-enterprise-alerts-topic"
}

# --- 2. IAM Role for Observability Lambda ---
resource "aws_iam_role" "lambda_role" {
  name = "ahmad_observability_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# --- 3. Lambda Function for Telegram Forwarding ---
resource "aws_lambda_function" "telegram_forwarder" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "ahmad-telegram-alarm-forwarder"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      TELEGRAM_BOT_TOKEN = var.telegram_bot_token
      TELEGRAM_CHAT_ID   = var.telegram_chat_id
    }
  }
}

# --- 4. SNS to Lambda Subscription ---
resource "aws_sns_topic_subscription" "lambda_sub" {
  topic_arn = aws_sns_topic.alarm_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.telegram_forwarder.arn
}

resource "aws_lambda_permission" "with_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.telegram_forwarder.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alarm_topic.arn
}

# --- 5. CloudWatch Metric Alarm for ALB 5XX Errors ---
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "Ahmad-ALB-High-Error-Rate-Alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "3"
  alarm_description   = "Critical Error rate spiked on Ahmad Enterprise Platform"
  alarm_actions       = [aws_sns_topic.alarm_topic.arn]

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
}

# --- 6. Archive File Generator for Lambda Deployment ---
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"

  source {
    content  = <<-EOF
      import json
      import os
      import urllib.request

      def lambda_handler(event, context):
          bot_token = os.environ.get('TELEGRAM_BOT_TOKEN')
          chat_id = os.environ.get('TELEGRAM_CHAT_ID')

          sns_message = event['Records'][0]['Sns']['Message']
          telegram_msg = f"🚨 *URGENT AWS ENTERPRISE ALARM* 🚨\n\nDetails:\n{sns_message}"

          url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
          data = json.dumps({"chat_id": chat_id, "text": telegram_msg, "parse_mode": "Markdown"}).encode('utf-8')

          req = urllib.request.Request(url, data=data, headers={'Content-Type': 'application/json'})
          with urllib.request.urlopen(req) as response:
              return response.read().decode('utf-8')
      EOF
    filename = "lambda_function.py"
  }
}
