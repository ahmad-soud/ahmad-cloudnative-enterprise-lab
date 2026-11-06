# --- 1. DB Subnet Group for Isolated Data Subnets ---
resource "aws_db_subnet_group" "postgres_subnets" {
  name       = "ahmad-enterprise-rds-subnet-group"
  subnet_ids = var.isolated_data_subnet_ids
  tags       = { Name = "Ahmad-RDS-SubnetGroup" }
}

# --- 2. Security Group for PostgreSQL Database ---
resource "aws_security_group" "rds_sg" {
  name        = "ahmad-enterprise-rds-sg"
  description = "Allow PostgreSQL traffic exclusively from ECS Tasks Security Group"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.ecs_task_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "Ahmad-RDS-SG" }
}

# --- 3. Encrypted RDS PostgreSQL Instance ---
resource "aws_db_instance" "postgres" {
  identifier             = "ahmad-enterprise-db"
  allocated_storage      = 20
  max_allocated_storage  = 100
  db_name                = "users_db"
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t3.micro"

  username               = "ahmad_user"
  password               = "SuperSecureEnterprisePassword2026_KMS"

  db_subnet_group_name   = aws_db_subnet_group.postgres_subnets.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true

  storage_encrypted      = true
  kms_key_id             = var.kms_key_arn

  tags = { Name = "Ahmad-Enterprise-Postgres" }
}

output "db_endpoint" { value = aws_db_instance.postgres.endpoint }
