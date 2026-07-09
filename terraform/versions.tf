terraform {
  required_version = ">= 1.9"

  # Remote state stored in S3, locked via DynamoDB.
  # Run terraform/bootstrap/ once first to create the bucket and table,
  # then fill in the values below with the bootstrap outputs.
  backend "s3" {
    bucket         = "simpletimeservice-tf-state"
    key            = "simpletimeservice/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "simpletimeservice-tf-lock"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}
