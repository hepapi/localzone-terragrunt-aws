module "iam_iam-user" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  version = "5.48.0"

  for_each = toset(var.user_names)  

  name                  = each.value 
  create_iam_access_key = false 
  create_iam_user_login_profile = true
  force_destroy = true
  password_length       = 12      
  password_reset_required = true
}