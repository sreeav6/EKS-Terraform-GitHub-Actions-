output "namespace" {
  description = "Kubernetes namespace the application was deployed into."
  value       = kubernetes_namespace.app.metadata[0].name
}

output "load_balancer_hostname" {
  description = "Public DNS hostname of the ALB. May be null immediately after apply — run terraform refresh if so."
  value       = try(kubernetes_ingress_v1.app.status[0].load_balancer[0].ingress[0].hostname, null)
}
