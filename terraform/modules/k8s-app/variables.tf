variable "project_name" {
  description = "Used as the Kubernetes namespace name, Deployment name, and app selector label."
  type        = string
}

variable "container_image" {
  description = "Fully-qualified container image (registry/repo:tag)."
  type        = string
}

variable "container_port" {
  description = "Port the application container listens on."
  type        = number
  default     = 8080
}

variable "replica_count" {
  description = "Number of pod replicas in the Deployment."
  type        = number
  default     = 2
}

variable "public_subnet_ids" {
  description = "Public subnet IDs the ALB will be provisioned in."
  type        = list(string)
}

variable "cluster_name" {
  description = "EKS cluster name — used by destroy-time provisioners to run aws eks update-kubeconfig."
  type        = string
}

variable "aws_region" {
  description = "AWS region — used by destroy-time provisioners to authenticate against the cluster."
  type        = string
}
