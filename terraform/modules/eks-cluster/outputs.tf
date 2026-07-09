output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "URL of the Kubernetes API server."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded CA certificate for the cluster."
  value       = module.eks.cluster_certificate_authority_data
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider — used by IRSA in the lb-controller module."
  value       = module.eks.oidc_provider_arn
}

# Downstream modules depend on this output (via depends_on) to ensure
# the bootstrap sleep has completed before making Kubernetes API calls.
output "cluster_ready" {
  description = "Opaque sentinel — ready after the bootstrap sleep completes."
  value       = time_sleep.wait_for_cluster.id
}
