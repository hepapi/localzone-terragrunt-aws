module "lb_role" {
 source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
 version = "~> 5.52.0"

 role_name                              = "eks-lb-controller-${var.cluster_name}"
 attach_load_balancer_controller_policy = true

 oidc_providers = {
     main = {
     provider_arn               = var.oidc_provider_arn
     namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
     }
 }
 }

 resource "kubernetes_service_account" "service-account" {
 metadata {
     name      = "aws-load-balancer-controller"
     namespace = "kube-system"
     labels = {
     "app.kubernetes.io/name"      = "aws-load-balancer-controller"
     "app.kubernetes.io/component" = "controller"
     }
     annotations = {
     "eks.amazonaws.com/role-arn"               = module.lb_role.iam_role_arn
     "eks.amazonaws.com/sts-regional-endpoints" = "true"
     }
 }
 }