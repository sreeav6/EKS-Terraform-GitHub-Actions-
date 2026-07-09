# ── bootstrap/main.tf ─────────────────────────────────────────────────────────
# Run this ONCE before your first `terraform init` in the parent terraform/
# directory. It creates the S3 bucket and DynamoDB table that Terraform will
# use for remote state storage and state locking.
#
# Usage:
#   cd terraform/bootstrap
#   terraform init
#   terraform apply
# ──────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ── S3 bucket — stores terraform.tfstate ──────────────────────────────────────
resource "aws_s3_bucket" "tf_state" {
  bucket = var.state_bucket_name

  # Prevent accidental deletion of the bucket that holds your state.
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Project   = "simpletimeservice"
    ManagedBy = "terraform-bootstrap"
    Purpose   = "terraform-state"
  }
}

# Block every form of public access — state files contain sensitive values.
resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning so you can roll back to any previous state file.
resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt state at rest using the default AWS-managed key (SSE-S3).
# Swap to aws:kms and supply a key ARN for stricter key management.
resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ── DynamoDB table — provides state locking and consistency checks ─────────────
resource "aws_dynamodb_table" "tf_lock" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST" # no capacity planning needed
  hash_key     = "LockID"          # required field name — do not change

  attribute {
    name = "LockID"
    type = "S"
  }

  # Protect the lock table from accidental deletion just like the bucket.
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Project   = "simpletimeservice"
    ManagedBy = "terraform-bootstrap"
    Purpose   = "terraform-state-lock"
  }
}
