module "iam_groups" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-group-with-policies"
  version = "5.48.0"

 
  for_each = var.groups

  name                        = each.value.group_name
  group_users                 = each.value.group_users
  custom_group_policy_arns    = each.value.policy_arns
  attach_iam_self_management_policy = false
}