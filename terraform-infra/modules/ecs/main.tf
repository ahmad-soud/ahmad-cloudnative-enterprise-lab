resource "aws_ecr_repository" "enterprise_api_repo" {
  name                 = "ahmad-enterprise-api"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = { Name = "Ahmad-Enterprise-API-Registry" }
}

output "ecr_repository_url" {
  value       = aws_ecr_repository.enterprise_api_repo.repository_url
  description = "The secure URL of your private AWS ECR repository"
}

# --- 1. ECS Cluster ---
resource "aws_ecs_cluster" "main" {
  name = "ahmad-enterprise-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Name = "Ahmad-Enterprise-ECS-Cluster" }
}

# --- 2. CloudWatch Log Group for Container Logs ---
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/ahmad-enterprise-api"
  retention_in_days = 30

  tags = { Name = "Ahmad-Enterprise-LogGroup" }
}

# --- 3. IAM Execution Role ---
resource "aws_iam_role" "ecs_execution_role" {
  name = "ahmad_ecs_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- 4. ECS Task Definition ---
resource "aws_ecs_task_definition" "app" {
  family                   = "ahmad-enterprise-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "ahmad-enterprise-api"
      image     = "${aws_ecr_repository.enterprise_api_repo.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = "eu-central-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = { Name = "Ahmad-Enterprise-TaskDef" }
}

output "ecs_cluster_id" {
  value       = aws_ecs_cluster.main.id
  description = "The ID of the ECS Cluster"
}

output "ecs_task_definition_arn" {
  value       = aws_ecs_task_definition.app.arn
  description = "The ARN of the ECS Task Definition"
}

# --- 5. Security Group for Application Load Balancer ---
resource "aws_security_group" "alb_sg" {
  name        = "ahmad-alb-sg"
  description = "Allow public HTTP traffic from internet to ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "Ahmad-ALB-SG" }
}

# --- 6. Application Load Balancer (ALB) ---
resource "aws_lb" "main" {
  name               = "ahmad-enterprise-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnet_ids

  tags = { Name = "Ahmad-Enterprise-ALB" }
}

# --- 7. Target Group for ECS Tasks ---
resource "aws_lb_target_group" "app" {
  name        = "ahmad-enterprise-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/docs"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = { Name = "Ahmad-Enterprise-TG" }
}

# --- 8. ALB Listener ---
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# --- 9. Secure Security Group for ECS Tasks ---
resource "aws_security_group" "ecs_task_sg" {
  name        = "ahmad-ecs-task-sg"
  description = "Allow inbound traffic exclusively from ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "Ahmad-ECS-Task-SG" }
}

# --- 10. ECS Service ---
resource "aws_ecs_service" "app" {
  name            = "ahmad-enterprise-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_app_subnet_ids
    security_groups  = [aws_security_group.ecs_task_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "ahmad-enterprise-api"
    container_port   = 8000
  }

  depends_on = [aws_lb_listener.http]

  tags = { Name = "Ahmad-Enterprise-Service" }
}

# --- Output: ALB DNS Name ---
output "alb_dns_name" {
  value       = aws_lb.main.dns_name
  description = "The public DNS name of the Application Load Balancer"
}
output "alb_arn_suffix" {
  value = aws_lb.main.arn_suffix
}

output "ecs_task_sg_id" {
  value       = aws_security_group.ecs_task_sg.id
  description = "Security Group ID for ECS Tasks"
}

output "alb_arn" {
  value       = aws_lb.main.arn
  description = "The full Amazon Resource Name of the Application Load Balancer"
}
