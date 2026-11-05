# --- 1. KMS Key for Enterprise Encryption ---
resource "aws_kms_key" "enterprise_key" {
  description             = "KMS Key for Ahmad Enterprise Platform Database and Secrets encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = { Name = "ahmad-enterprise-kms-key" }
}

# --- 2. KMS Key Alias ---
resource "aws_kms_alias" "enterprise_key_alias" {
  name          = "alias/ahmad-enterprise-key"
  target_key_id = aws_kms_key.enterprise_key.key_id
}

# --- 3. Secrets Manager Secret Container ---
resource "aws_secretsmanager_secret" "db_secret" {
  name                    = "ahmad-enterprise-db-credentials-v1"
  kms_key_id              = aws_kms_key.enterprise_key.arn
  recovery_window_in_days = 0

  tags = { Name = "Ahmad-Enterprise-DB-Secrets" }
}

# --- 4. Secrets Manager Secret Version ---
resource "aws_secretsmanager_secret_version" "db_secret_val" {
  secret_id     = aws_secretsmanager_secret.db_secret.id
  secret_string = jsonencode({
    username = "ahmad_enterprise_admin"
    password = "SuperSecureEnterprisePassword2026_KMS"
  })
}

output "kms_key_arn" { value = aws_kms_key.enterprise_key.arn }
output "secret_arn" { value = aws_secretsmanager_secret.db_secret.arn }
