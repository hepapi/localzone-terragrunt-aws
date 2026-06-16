terraform {
  source = "tfr:///terraform-aws-modules/eks/aws//modules/eks-managed-node-group//?version=${local.env_vars.locals.module_versions.node-group}"
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

dependency "vpc" {
  config_path = "${find_in_parent_folders("vpc")}"
  mock_outputs = {
    vpc_id          = "vpc-123456"
    private_subnets = ["subnet-1234", "subnet-4321", "subnet-3241"]
  }
}

dependency "common-security-group" {
  config_path = find_in_parent_folders("common-security-group")
  mock_outputs = {
    security_group_id = "sg-1111111111"
  }
}

dependency "eks" {
  config_path = find_in_parent_folders("eks")
  mock_outputs = {
    cluster_endpoint                   = "https://1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A.gr7.eu-west-1.eks.amazonaws.com"
    cluster_certificate_authority_data = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURCVENDQWUyZ0F3SUJBZ0lJV24rTVZ4NWM3NDh3RFFZSktvWklodmNOQVFFTEJRQXdGVEVUTUJFR0ExVUUKQXhNS2EzVmlaWEp1WlhSbGN6QWVGdzB5TkRFeE1EWXdOekkzTXpGYUZ3MHpOREV4TURRd056TXlNekZhTUJVeApFekFSQmdOVkJBTVRDbXQxWW1WeWJtVjBaWE13Z2dFaU1BMEdDU3FHU0liM0RRRUJBUVVBQTRJQkR3QXdnZ0VLCkFvSUJBUURQR0FPWlpNUTdTdGZMTGtmQlpMSFNSYmE2VXFoeUJBY1RXNTRhbHUxS1JEZUpEV3N4aFJQUlUza3MKb2YzY1NkcWo4WWFTRUJmTHByd3hqeUF6ZHZoL1ZmRnhQRWlxeGRSMXBkVm95VTBWY201U05qWU10RzczT01megpnTUtva3Rlb253N3NSODFrMXVER1U1NVJNakhnOTExME4xejBaZWZUbHhCbGIwbG9hNHNra04wRmJYVTZ6MVg3CkdRTzVYa1J1K0ZIS1UwVWJoNytIaEN5V3BGeTlqWkFLbExiOGpWRnQyK1hSbHRFMjh2QlBiZm9IRkIxckhKRmoKN2tIdDJXRmdmUUZYZ21HOVhiekZDOE0wc2ZqNnViOUl2dkxKL2czRHEyc3dhQnFTZDFZanlybGlwSDhuc0VQbgpBVmJ0RU1oQlFhVHJyZU1CQ3VzTDAyQkk1K2VwQWdNQkFBR2pXVEJYTUE0R0ExVWREd0VCL3dRRUF3SUNwREFQCkJnTlZIUk1CQWY4RUJUQURBUUgvTUIwR0ExVWREZ1FXQkJTNUFCR3d4cGVzMDcvS1lna0hyNllDakpOYkxUQVYKQmdOVkhSRUVEakFNZ2dwcmRXSmxjbTVsZEdWek1BMEdDU3FHU0liM0RRRUJDd1VBQTRJQkFRQk1WOE1DWXBhTwpQb0haL0FZWnA5S0tzLzhlNXg1dkMwUVU0NHdmSkMxcDgxZmZ6MC9nMzJtVndKem4venZ2WkxrT1ZmKzN2WlVGCnQ3dDhaVzdqNlZyVi9LeUw1allyaE1CZWl4empjMGZCRFQySzFGdUF5YlNJT0gwNlhLN3pPT3NEdUhQYXAxUm8KNzI3eGUycndxajd0TGt5VzVOZWp1MlVacUVySFZZYUZFS3Vhc2g3OWswREc1WUhORkQzWHZ0WGxrUXBiRmdJZwpmU1NoOGQzbFEwYUZvSU9SMDBrMytJUHljUU5vQ1R0MEIycWNTRkRsSXlxcHNzSXBYeXdJQmlVNXpyYUxFcG9ICjJITkdmdEgzVjR5bDFaUXR1aFU1WE1TZmh4b1RtdUtGdjdiVmtFOExzVzBWV0UxcnpFbXY0QkVUSmNiMlFqSSsKMFJ3N2JoVUdLalF2Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K"
    cluster_name                       = "demo-cluster"
    cluster_version                    = "1.1.1"
    oidc_provider                      = "arn:aws:iam::1111111111:oidc-provider/oidc.eks.eu-west-1.amazonaws.com/id/AB12"
    oidc_provider_arn                  = "arn:aws:iam::111111111111:oidc-provider/oidc.eks.eu-west-1.amazonaws.com/id/AB12"
    node_security_group_id             = "sg-1234567890"
  }
}


inputs = {
  name            = local.env_vars.locals.node_groups.name
  cluster_name    = dependency.eks.outputs.cluster_name
  cluster_version = dependency.eks.outputs.cluster_version

  subnet_ids = slice(dependency.vpc.outputs.private_subnets, 2, 3)
  vpc_security_group_ids = [dependency.eks.outputs.node_security_group_id, dependency.common-security-group.outputs.security_group_id]
  cluster_service_cidr = local.env_vars.locals.node_groups.cluster_service_cidr
  iam_role_name = local.env_vars.locals.node_groups.iam_role_name
  launch_template_name = local.env_vars.locals.node_groups.launch_template_name

  min_size     = local.env_vars.locals.node_groups.min_size
  max_size     = local.env_vars.locals.node_groups.max_size
  desired_size = local.env_vars.locals.node_groups.desired_size

  instance_types = local.env_vars.locals.node_groups.instance_types
  capacity_type  = local.env_vars.locals.node_groups.capacity_type
  update_config  = local.env_vars.locals.node_groups.update_config

  disk_size             = local.env_vars.locals.node_groups.disk_size
    block_device_mappings = {
      xvda = {
        device_name = "/dev/xvda"
        ebs         = {
          volume_size           = local.env_vars.locals.node_groups.disk_size
          volume_type           = "gp3"
        }
      }
    }

  iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  labels = local.env_vars.locals.node_groups.labels

  tags = {
    Environment = "Terragrunt"
    Name        = local.env_vars.locals.node_groups.name
  }
}