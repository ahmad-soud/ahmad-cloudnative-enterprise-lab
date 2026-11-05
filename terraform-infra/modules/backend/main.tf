# --- 1. S3 Bucket for Secure Remote Terraform State Storage ---
resource "aws_s3_bucket" "state_bucket" {
  bucket        = "ahmad-enterprise-tfstate-vault-2026"
  force_destroy = true

  tags = { Name = "Ahmad-Enterprise-TFState-Bucket" }
}

# --- 2. Enable Versioning for State History Recovery ---
resource "aws_s3_bucket_versioning" "state_versioning" {
  bucket = aws_s3_bucket.state_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# --- 3. Enable Server-Side Encryption (AES256) ---
resource "aws_s3_bucket_server_side_encryption_configuration" "state_encryption" {
  bucket = aws_s3_bucket.state_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# --- 4. Block Public Access for Enhanced Security ---
resource "aws_s3_bucket_public_access_block" "state_public_access_block" {
  bucket = aws_s3_bucket.state_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- 5. DynamoDB Table for State Locking (Concurrency Control) ---
resource "aws_dynamodb_table" "state_locks" {
  name         = "ahmad-enterprise-tflocks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = { Name = "Ahmad-Enterprise-TFLocks-Table" }
}
