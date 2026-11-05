terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

   #--- Phase 0: S3 Remote Backend Configuration (Uncomment after initial apply) ---
   #backend "s3" {
   #   bucket         = "ahmad-enterprise-tfstate-vault-2026"
   #   key            = "prod/terraform.tfstate"
   #   region         = "eu-central-1"
   #   dynamodb_table = "ahmad-enterprise-tflocks"
   #   encrypt        = true
   #}
}

provider "aws" {
  region = "eu-central-1"
}

# --- Input Variables for Sensitive Alerting Parameters ---
variable "telegram_bot_token" {
  type        = string
  description = "Telegram Bot Token for alerts"
  sensitive   = true
}

variable "telegram_chat_id" {
  type        = string
  description = "Telegram Chat ID for alerts"
}

# --- Phase 0: State Backend and Locking Module ---
module "state_backend" {
  source = "../../modules/backend"
}

# --- Phase 1: Network Layer (VPC, Subnets, Gateways) ---
module "network_layer" {
  source = "../../modules/vpc"

  vpc_cidr            = "10.0.0.0/16"
  availability_zones  = ["eu-central-1a", "eu-central-1b"]

  public_subnet_cidrs        = ["10.0.1.0/24", "10.0.2.0/24"]
  private_app_subnet_cidrs   = ["10.0.11.0/24", "10.0.12.0/24"]
  isolated_data_subnet_cidrs = ["10.0.21.0/24", "10.0.22.0/24"]
}

# --- Phase 2: Compute & Container Layer (ECS Fargate & ALB) ---
module "ecs_layer" {
  source = "../../modules/ecs"

  vpc_id                 = module.network_layer.vpc_id
  public_subnet_ids      = module.network_layer.public_subnet_ids
  private_app_subnet_ids = module.network_layer.private_app_subnet_ids
}

# --- Phase 3: Messaging & Queue Layer (SQS & DLQ) ---
module "sqs_layer" {
  source = "../../modules/sqs"
}

# --- Phase 5 & 9: Observability & Alerting Layer ---
module "observability_layer" {
  source             = "../../modules/observability"
  alb_arn_suffix     = module.ecs_layer.alb_arn_suffix
  telegram_bot_token = var.telegram_bot_token
  telegram_chat_id   = var.telegram_chat_id
}

# --- Phase 4: Security, Encryption & Secrets Manager Layer ---
module "security_layer" {
  source = "../../modules/security"
}

# --- Phase 4b: Isolated Database Layer (RDS PostgreSQL) ---
module "rds_layer" {
  source = "../../modules/rds"

  vpc_id                   = module.network_layer.vpc_id
  isolated_data_subnet_ids = module.network_layer.isolated_data_subnet_ids
  kms_key_arn              = module.security_layer.kms_key_arn
  ecs_task_sg_id           = module.ecs_layer.ecs_task_sg_id
}

# --- Phase 6: Edge Security Layer (AWS WAFv2 Hardening) ---
module "waf_layer" {
  source  = "../../modules/waf"
  alb_arn = module.ecs_layer.alb_arn
}

# --- Centralized Architecture Outputs ---
output "deployed_vpc_id" { value = module.network_layer.vpc_id }
output "ecr_repository_url" { value = module.ecs_layer.ecr_repository_url }
output "alb_public_url" { value = module.ecs_layer.alb_dns_name }
output "sqs_queue_url" { value = module.sqs_layer.queue_id }
output "secrets_manager_arn" { value = module.security_layer.secret_arn }
output "database_endpoint" { value = module.rds_layer.db_endpoint }
output "waf_web_acl_arn" { value = module.waf_layer.web_acl_arn }
