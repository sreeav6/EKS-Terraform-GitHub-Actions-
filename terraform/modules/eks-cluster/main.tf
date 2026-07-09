# EKS Auto Mode lets AWS manage node lifecycle, scaling, and patching
# automatically — no managed node groups or Karpenter configuration required.
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${var.project_name}-cluster"
  cluster_version = var.kubernetes_version

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids # control plane ENIs in private subnets

  cluster_compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  # Expose the API server publicly so the Terraform Kubernetes/Helm providers
  # (running on your local machine) can reach it.
  cluster_endpoint_public_access = true

  # Grant the IAM identity executing Terraform cluster-admin rights
  # automatically — avoids the manual aws-auth ConfigMap step.
  enable_cluster_creator_admin_permissions = true

  tags = var.tags
}

# Pause briefly after the cluster is created so the Kubernetes API server
# is fully ready before downstream providers make their first call.
resource "time_sleep" "wait_for_cluster" {
  create_duration = "30s"
  depends_on      = [module.eks]
}
