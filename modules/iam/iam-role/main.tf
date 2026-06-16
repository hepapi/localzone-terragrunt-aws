module "iam_assumable_roles" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-roles"
  version = "5.48.0"

  create_poweruser_role    = var.create_poweruser_role
  poweruser_role_name      = var.poweruser_role_name
  poweruser_role_policy_arns = var.poweruser_role_policy_arns
  trusted_role_arns        = var.trusted_role_arns
}