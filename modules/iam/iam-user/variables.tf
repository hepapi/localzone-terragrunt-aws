variable "user_names" {
  description = "List of user names to create"
  type        = list(string)
}

variable "aws_account_id" {
  description = "The AWS Account ID for console login URL"
  type        = string
}