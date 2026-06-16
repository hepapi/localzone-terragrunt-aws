output "aws_console_login_details" {
  description = "AWS Console login details for users"
  value = [
    for user in module.iam_iam-user :
    {
      console_url = "https://${var.aws_account_id}.signin.aws.amazon.com/console"
      user_name   = user.iam_user_name
      password    = user.iam_user_login_profile_password
    }
  ]
  sensitive = true
}