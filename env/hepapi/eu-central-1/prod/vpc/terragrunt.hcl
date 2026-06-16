terraform {
  source = "tfr:///terraform-aws-modules/vpc/aws//?version=${local.env_vars.locals.module_versions.vpc}"
}

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

inputs = {
  name             = "${local.env_vars.locals.vpc.vpc_name}-vpc"
  cidr             = local.env_vars.locals.vpc.cidr
  azs              = local.env_vars.locals.vpc.azs
  private_subnets  = local.env_vars.locals.vpc.private_subnets
  public_subnets   = local.env_vars.locals.vpc.public_subnets

  create_database_subnet_group       = false
  create_database_subnet_route_table = false

  enable_nat_gateway     = local.env_vars.locals.vpc.enable_nat_gateway
  enable_vpn_gateway     = local.env_vars.locals.vpc.enable_vpn_gateway
  single_nat_gateway     = local.env_vars.locals.vpc.single_nat_gateway
  one_nat_gateway_per_az = local.env_vars.locals.vpc.one_nat_gateway_per_az

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    ManagedBy = "Terragrunt"
    Environment = include.root.locals.env
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb"                                            = 1
    "kubernetes.io/cluster/${local.env_vars.locals.eks.cluster_name}" = "shared"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"                                     = 1
    "kubernetes.io/cluster/${local.env_vars.locals.eks.cluster_name}" = "shared"
    "karpenter.sh/discovery/${local.env_vars.locals.eks.cluster_name}"  = "${local.env_vars.locals.eks.cluster_name}"

  }
}
