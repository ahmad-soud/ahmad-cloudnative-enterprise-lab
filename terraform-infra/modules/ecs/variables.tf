variable "vpc_id" {
  type        = string
  description = "The VPC ID where ECS security groups will be created"
}

variable "private_app_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for ECS Fargate tasks"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "List of public subnet IDs for the Application Load Balancer"
}
