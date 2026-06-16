variable "create_poweruser_role" {
  description = "Whether to create the poweruser role"
  type        = bool
  default     = true
}

variable "poweruser_role_name" {
  description = "Name of the poweruser IAM role"
  type        = string
  default     = "eks-cluster-role"
}

variable "poweruser_role_policy_arns" {
  description = "List of policy ARNs to attach to the poweruser role"
  type        = list(string)
}

variable "trusted_role_arns" {
  description = "List of user ARNs who can assume the poweruser role"
  type        = list(string)
}