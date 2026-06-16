terraform {
  source = "tfr:///terraform-aws-modules/eks/aws//?version=${local.env_vars.locals.module_versions.eks}"
  after_hook "after_hook" {
    commands = ["apply"]
    execute = [
      "aws",
      "eks",
      "update-kubeconfig",
      "--region",
      "${include.root.locals.region}",
      "--name",
      "${local.env_vars.locals.eks.cluster_name}",
      "--profile",
      "${local.env_vars.locals.aws_profile}"
    ]
  }
}

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

}

dependency "vpc" {
  config_path = "${find_in_parent_folders("vpc")}"
  mock_outputs = {
    vpc_id          = "vpc-123456"
    private_subnets = ["subnet-1234", "subnet-4321"]
  }
}
inputs = {
  cluster_name    = local.env_vars.locals.eks.cluster_name
  cluster_version = local.env_vars.locals.eks.cluster_version
  vpc_id          = dependency.vpc.outputs.vpc_id
  # Local zone subnets not supported for EKS control plane; use only parent-region subnets (index 0,1 = eu-central-1a/b)
  subnet_ids      = slice(dependency.vpc.outputs.private_subnets, 0, 2)

  authentication_mode                  = local.env_vars.locals.eks.authentication_mode
  cluster_endpoint_public_access_cidrs = local.env_vars.locals.eks.cluster_endpoint_public_access_cidrs
  create_iam_role                      = local.env_vars.locals.eks.create_iam_role
  enable_irsa                          = local.env_vars.locals.eks.enable_irsa
  attach_cluster_encryption_policy     = local.env_vars.locals.eks.attach_cluster_encryption_policy

  upgrade_policy = {
    support_type = local.env_vars.locals.eks.support_type
  }

  cluster_endpoint_private_access = local.env_vars.locals.eks.cluster_endpoint_private_access
  cluster_endpoint_public_access  = local.env_vars.locals.eks.cluster_endpoint_public_access
  cluster_service_ipv4_cidr       = local.env_vars.locals.eks.cluster_service_ipv4_cidr

  enable_cluster_creator_admin_permissions = local.env_vars.locals.eks.enable_cluster_creator_admin_permissions

  kms_key_aliases = local.env_vars.locals.eks.kms_key_aliases

  access_entries = local.env_vars.locals.eks.access_entries

  kms_key_administrators = local.env_vars.locals.eks.kms_key_administrators

  cluster_addons = {
  coredns = {
    addon_name    = "coredns"
    addon_version = local.env_vars.locals.eks.cluster_addons.coredns_addon_version
  }
    eks-pod-identity-agent = {
    }
    vpc-cni = {
      addon_version = local.env_vars.locals.eks.cluster_addons.vpc-cni_addon_version
      configuration_values = jsonencode({
        env = {
          # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
  }

  node_security_group_tags = {
    "karpenter.sh/discovery/${local.env_vars.locals.eks.cluster_name}" = local.env_vars.locals.eks.cluster_name
  }

  tags = {
    Name        = local.env_vars.locals.eks.cluster_name
    Environment = include.root.locals.env
    ManagedBy   = "Terragrunt"
  }
}