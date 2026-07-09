output "iam_role_arn" {
  description = "ARN of the IRSA role attached to the controller's service account."
  value       = module.lbc_irsa.iam_role_arn
}
