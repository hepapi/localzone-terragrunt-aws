locals {
  region = "eu-central-1"
  env = basename(get_terragrunt_dir())
  aws_profile = "hepapi-sso"
  
  not_create = {
    kms = true
    bastion = true
    fargate = true
    ingress-nginx = true
    internal-ingress-nginx = true
    aurora = true
    postgresql = true
    elasticache = true
    documentdb= true
    waf = true
  }
  module_versions = {
    vpc = "6.6.0"
    eks = "20.33.1"
    iam_attach_efs_role = "5.52.2"     #### iam_iam-role-for-service-accounts-eks module
    fargate = "20.33.1"
    karpenter-module = "20.33.1"
    efs = "1.6.5"
    security-group = "5.3.0"
    ec2 = "5.7.1"
    keypair = "2.0.3"
    s3 = "4.5.0"
  }

  helm_versions = {
    efs-csi-chart       = "3.1.5"
    argocd-chart        = "7.8.5"
    argocd-app-chart    = "2.0.2"
    karpenter-chart     = "1.1.2"
    aws-load-balancer-controller = "1.11.0"
  }


}