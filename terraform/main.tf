data "aws_caller_identity" "current" {}

# ── 1. Networking ─────────────────────────────────────────────────────────────
module "networking" {
  source = "./modules/networking"

  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  tags                 = var.tags
}

# ── 2. EKS Cluster ────────────────────────────────────────────────────────────
module "eks_cluster" {
  source = "./modules/eks-cluster"

  project_name       = var.project_name
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  tags               = var.tags
}

# ── 3. AWS Load Balancer Controller ───────────────────────────────────────────
module "lb_controller" {
  source = "./modules/lb-controller"

  project_name      = var.project_name
  aws_region        = var.aws_region
  cluster_name      = module.eks_cluster.cluster_name
  oidc_provider_arn = module.eks_cluster.oidc_provider_arn
  vpc_id            = module.networking.vpc_id

  depends_on = [module.eks_cluster]
}

# ── 4. Application workload ───────────────────────────────────────────────────
module "k8s_app" {
  source = "./modules/k8s-app"

  project_name      = var.project_name
  container_image   = var.container_image
  replica_count     = var.replica_count
  public_subnet_ids = module.networking.public_subnet_ids
  cluster_name      = module.eks_cluster.cluster_name
  aws_region        = var.aws_region

  depends_on = [module.lb_controller]
}
