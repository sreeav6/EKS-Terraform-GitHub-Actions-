variable "aws_region" {
  description = "AWS region to deploy all resources into."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short identifier used as a prefix for every resource and Kubernetes object name."
  type        = string
  default     = "simpletimeservice"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.32"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the two public subnets (one per AZ). The ALB lives here."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the two private subnets (one per AZ). Pods run here."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "container_image" {
  description = "Fully-qualified image reference for SimpleTimeService (registry/repo:tag)."
  type        = string
  default     = "docker.io/anilsree/simpletimeservice:latest"
}

variable "replica_count" {
  description = "Number of pod replicas for the Deployment."
  type        = number
  default     = 2
}

variable "tags" {
  description = "AWS resource tags applied to every resource in the stack."
  type        = map(string)
  default = {
    Project   = "simpletimeservice"
    ManagedBy = "terraform"
  }
}
