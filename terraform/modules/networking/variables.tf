variable "project_name" {
  description = "Prefix applied to every resource name."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets — one per AZ."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets — one per AZ."
  type        = list(string)
}

variable "tags" {
  description = "Tags applied to every AWS resource in this module."
  type        = map(string)
  default     = {}
}
