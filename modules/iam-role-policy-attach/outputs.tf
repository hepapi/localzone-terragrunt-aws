output "role_name" {
  description = "Name of the IAM role with attached policies"
  value       = var.role_name
}

output "attached_policy_arns" {
  description = "List of policy ARNs attached to the role"
  value       = var.policy_arns
}
