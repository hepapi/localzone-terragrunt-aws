terraform {
  source = "tfr:///terraform-aws-modules/eks/aws//modules/karpenter//?version=${local.env_vars.locals.module_versions.karpenter-module}"
}

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

dependency "eks" {
  config_path = find_in_parent_folders("eks")
  mock_outputs = {
    cluster_name      = "demo-cluster"
    oidc_provider_arn = "arn:aws:iam::111111111111:oidc-provider/oidc.eks.eu-west-1.amazonaws.com/id/AB12"
  }
}

inputs = {
  cluster_name = dependency.eks.outputs.cluster_name

  enable_v1_permissions           = true
  enable_irsa                     = true
  enable_pod_identity             = true
  create_pod_identity_association = true
  irsa_oidc_provider_arn          = dependency.eks.outputs.oidc_provider_arn
  irsa_namespace_service_accounts = [
    "karpenter:karpenter"
  ]

  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = {
    Name        = "${include.root.locals.env}-eks"
    Environment = include.root.locals.env
    ManagedBy   = "Terragrunt"
  }

}