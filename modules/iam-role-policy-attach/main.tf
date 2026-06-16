resource "aws_iam_role_policy_attachment" "role_policy_attachment" {
  for_each = toset(var.policy_arns)

  role       = var.role_name
  policy_arn = each.value
}
