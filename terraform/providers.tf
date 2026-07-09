provider "aws" {
  region = var.aws_region
}

# Retrieve a short-lived token for the Kubernetes and Helm providers.
# This data source re-runs on every plan/apply, so the token never expires
# mid-run even on large applies.
data "aws_eks_cluster_auth" "cluster" {
  name       = module.eks_cluster.cluster_name
  depends_on = [module.eks_cluster]
}

provider "kubernetes" {
  host                   = module.eks_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks_cluster.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}
