data "aws_availability_zones" "available" {
  state = "available"
}

# Build the VPC, public subnets (for the ALB), and private subnets (for pods).
# A single NAT Gateway is enough for a demo; switch single_nat_gateway to false
# and add one NAT GW per AZ for a production setup.
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Subnet tags required by the AWS Load Balancer Controller and EKS Auto Mode.
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = var.tags
}
