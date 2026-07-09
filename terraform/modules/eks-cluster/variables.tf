variable "project_name" {
  description = "Prefix applied to the cluster name and related resources."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC the cluster control plane ENIs are placed in."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the EKS control plane."
  type        = list(string)
}

variable "tags" {
  description = "Tags applied to every AWS resource in this module."
  type        = map(string)
  default     = {}
}
