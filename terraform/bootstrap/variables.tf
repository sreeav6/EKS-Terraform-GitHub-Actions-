variable "aws_region" {
  description = "AWS region where the S3 bucket and DynamoDB table are created."
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform state. Must be unique across all AWS accounts."
  type        = string
  default     = "simpletimeservice-tf-state"
}

variable "lock_table_name" {
  description = "DynamoDB table name used for Terraform state locking."
  type        = string
  default     = "simpletimeservice-tf-lock"
}
