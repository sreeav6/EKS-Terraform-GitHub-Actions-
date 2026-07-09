output "state_bucket_name" {
  description = "Copy this into the bucket field of your backend block in terraform/versions.tf."
  value       = aws_s3_bucket.tf_state.bucket
}

output "lock_table_name" {
  description = "Copy this into the dynamodb_table field of your backend block in terraform/versions.tf."
  value       = aws_dynamodb_table.tf_lock.name
}

output "backend_block" {
  description = "Ready-to-paste backend configuration for terraform/versions.tf."
  value       = <<-EOT
    backend "s3" {
      bucket         = "${aws_s3_bucket.tf_state.bucket}"
      key            = "simpletimeservice/terraform.tfstate"
      region         = "${aws_s3_bucket.tf_state.region}"
      dynamodb_table = "${aws_dynamodb_table.tf_lock.name}"
      encrypt        = true
    }
  EOT
}
