output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = module.eks_cluster.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint."
  value       = module.eks_cluster.cluster_endpoint
}

output "configure_kubectl" {
  description = "Run this command to point kubectl at the new cluster."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks_cluster.cluster_name}"
}

output "app_url" {
  description = "Public URL for SimpleTimeService. The ALB may take 2-3 minutes to become active after apply."
  value = (
    module.k8s_app.load_balancer_hostname != null
    ? "http://${module.k8s_app.load_balancer_hostname}"
    : "ALB hostname not yet available — run `terraform refresh` in a couple of minutes."
  )
}
