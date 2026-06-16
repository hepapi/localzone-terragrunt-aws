variable "groups" {
  description = "Groups with their respective users and policies"
  type = map(object({
    group_name  = string
    group_users = list(string)
    policy_arns = list(string)
  }))
}