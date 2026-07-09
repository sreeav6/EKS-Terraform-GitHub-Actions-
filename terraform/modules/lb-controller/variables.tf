variable "project_name" {
  description = "Prefix applied to the IRSA role name."
  type        = string
}

variable "aws_region" {
  description = "AWS region — passed through to the Helm chart values."
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster the controller will manage."
  type        = string
}

variable "oidc_provider_arn" {
  description = "OIDC provider ARN for the cluster — used to configure IRSA."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID — passed through to the Helm chart values."
  type        = string
}
