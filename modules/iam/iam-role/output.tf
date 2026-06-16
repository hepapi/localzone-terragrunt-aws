output "eks_role_arn" {
  description = "ARN of the EKS IAM role"
  value       = module.iam_assumable_roles.poweruser_iam_role_arn
}
