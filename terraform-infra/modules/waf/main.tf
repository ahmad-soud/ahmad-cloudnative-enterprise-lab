# --- 1. AWS WAFv2 Web ACL Definition ---
variable "alb_arn" {
  type        = string
  description = "The full ARN of the Application Load Balancer to associate with WAF"
}

resource "aws_wafv2_web_acl" "main" {
  name        = "ahmad-enterprise-waf"
  description = "Enterprise WAF to protect ALB against OWASP Top 10 vulnerabilities and DDoS attacks"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # --- Rule 1: Rate Limiting to Protect Against DoS Attacks ---
  rule {
    name     = "RateLimitRule"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 1000 # Limit to 1000 requests per 5 minutes per IP
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "WAFRateLimitMetric"
      sampled_requests_enabled   = true
    }
  }

  # --- Rule 2: AWS Managed Rules for SQL Injection (SQLi) Mitigation ---
  rule {
    name     = "AWSManagedRulesSQLi"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "WAFSQLiMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "AhmadEnterpriseWAFMetric"
    sampled_requests_enabled   = true
  }
}

# --- 2. WAF to Application Load Balancer Association ---
resource "aws_wafv2_web_acl_association" "alb_assoc" {
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

# --- Outputs ---
output "web_acl_arn" {
  value       = aws_wafv2_web_acl.main.arn
  description = "The ARN of the created WAFv2 Web ACL"
}
