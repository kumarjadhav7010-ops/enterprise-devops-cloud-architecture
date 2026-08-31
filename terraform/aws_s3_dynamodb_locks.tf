# Automated Remote State S3 Bucket & DynamoDB Lock Table Provisioner

resource "aws_kms_key" "tf_kms_key" {
  description             = "KMS Key for Terraform Remote State Encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket" "tf_state_bucket" {
  bucket        = "enterprise-devops-tfstate-storage-prod"
  force_destroy = false

  tags = {
    Name        = "Enterprise Terraform Remote State Bucket"
    Environment = "production"
  }
}

resource "aws_s3_bucket_versioning" "tf_state_versioning" {
  bucket = aws_s3_bucket.tf_state_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state_encryption" {
  bucket = aws_s3_bucket.tf_state_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.tf_kms_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_dynamodb_table" "tf_locks" {
  name         = "enterprise-tfstate-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "Enterprise Terraform State Lock Table"
    Environment = "production"
  }
}
