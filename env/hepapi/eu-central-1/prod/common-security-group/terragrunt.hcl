terraform {
  source = "tfr:///terraform-aws-modules/security-group/aws//?version=${local.env_vars.locals.module_versions.security-group}"
}

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

dependency "vpc" {
  config_path = find_in_parent_folders("vpc")
  mock_outputs = {
    vpc_id         = "vpc-1a1a1a1a1a1a1a1a1"
    vpc_cidr_block = "10.10.0.0/16"
  }
}

inputs = {
  name        = local.env_vars.locals.vpc.common_sg_name
  description = "Security group for common"
  vpc_id      = dependency.vpc.outputs.vpc_id

  ingress_with_cidr_blocks = [
    # {
    #   from_port   = 22
    #   to_port     = 22
    #   protocol    = "tcp"
    #   cidr_blocks = 10.0.65.0/24
    # },
  ]

  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  tags = {
    Name        = local.env_vars.locals.vpc.common_sg_name
    Environment = include.root.locals.env
    ManagedBy   = "Terragrunt"
  }
}