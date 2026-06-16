terraform {
  source = find_in_parent_folders("../../../modules/karpenter")
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
    cluster_endpoint                   = "https://1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A.gr7.eu-west-1.eks.amazonaws.com"
    cluster_certificate_authority_data = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURCVENDQWUyZ0F3SUJBZ0lJZldsSDhlTytUbzB3RFFZSktvWklodmNOQVFFTEJRQXdGVEVUTUJFR0ExVUUKQXhNS2EzVmlaWEp1WlhSbGN6QWVGdzB5TkRFd01UQXdPVEkzTkRsYUZ3MHpOREV3TURnd09UTXlORGxhTUJVeApFekFSQmdOVkJBTVRDbXQxWW1WeWJtVjBaWE13Z2dFaU1BMEdDU3FHU0liM0RRRUJBUVVBQTRJQkR3QXdnZ0VLCkFvSUJBUUN6VkVZdGZmR1ZDK3FUclBQRzZUc3JJQVVUdWp2dElFU0JnUDBqNENMbWg0VjFDU0tDOWs2SzRRdCsKNkl5SUVmSHk3aDhieEhnUi9rWEJ2eUdKNEt2MU9SUjQ2cCtwa29RY21nR2c3eHFXODdDS0RYTmhUTkJ0Q0JrYgpBV1lETnlSZEdmQUFxd2x6aVY3R2FYdmJTTkVVWit2YlY1WFBzeXIyWjhRTGRRUUFkZDgyajgvTFJlSDd1Mi9sCm1HU24yN09TZUVPdHQzSUJGUW51aHEyVkoxcjUzT1NhaVRuOFJwNTk5M2QzRTBUNkV3Vm5BclkzcTNEN2JhMFkKWmpjd3AzdE1TSWpLb21FMTZ3d0g0b2lGbUNkZGRkUDRpalI0K1VBdUN0TXRlajVOcVFJVUtITi9KblVIV1dxLwpLaStPb0Fra01ZTDNHL1ZTVnVMVzNUNVZwald0QWdNQkFBR2pXVEJYTUE0R0ExVWREd0VCL3dRRUF3SUNwREFQCkJnTlZIUk1CQWY4RUJUQURBUUgvTUIwR0ExVWREZ1FXQkJSeWU3L1RZbDRCZDUydUVMT3JnMFdUWWlBNUd6QVYKQmdOVkhSRUVEakFNZ2dwcmRXSmxjbTVsZEdWek1BMEdDU3FHU0liM0RRRUJDd1VBQTRJQkFRQ1QyTFNGREFEMgp2QWIySlFKVlF2WkErU0g5dGRJY0xTK3ZXM0N5aGhaMVVObXZqWXl5R00waDQ3Y1VvcDZtb0lhS0JxRnpPc1ZhCjVZdmpBWFBmazQvejNlR3F2aVRnZGxaK1o3K3VvTzYvYy9aU1prSU9TOTVaT01VdElvVTZPaEpVa2h5bUtydmEKVlFvQ0NVZXpSUUY2eGlrQktndlp2dURkbE9iU0FZanpEWHhKSGduMjhqRHRhTnd3MXBudHhSR2hxSWYrRzlxcwpUQWpXL21ENTgzbWFkZHlnSVZUbVN3d1ZoRzkxV0RzSkYySXNxcGJaRm5WRFZxZksrTzZ6NlM0ck41QmVKOFhnCjJUdis4VG1NV1RCZm5GZ1NLN2FlUmFDbFlyMkx4NG1xV2dkVGY2WVJISmdXcHlFamZ6emxUZ3E4T21WQk5UdVYKOHVQRjl5eVBqdm1YCi0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K"
    cluster_name                       = "demo-cluster"
  }
}

dependency "karpenter-module" {
  config_path = find_in_parent_folders("karpenter-module")
  mock_outputs = {
    queue_name         = "demo-queue"
    service_account    = "demo-serviceaccount"
    node_iam_role_name = "demo-iam-role"
  }
}

dependencies {
  paths = [find_in_parent_folders("karpenter-controller-helm")]
}

inputs = {
  amiAlias                     = local.env_vars.locals.eks.karpenter.amiAlias
  karpenter_node_iam_role_name = dependency.karpenter-module.outputs.node_iam_role_name
  diskSize                     = local.env_vars.locals.eks.karpenter.diskSize
  maxPods                      = local.env_vars.locals.eks.karpenter.maxPods
  eks_cluster_name             = dependency.eks.outputs.cluster_name
  userData                     = <<-EOF
    #!/bin/bash
    echo "Running custom user data script"
    sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
    sudo systemctl status amazon-ssm-agent
  EOF

  subnet_selector_tags = {
    "karpenter.sh/discovery/${dependency.eks.outputs.cluster_name}" = dependency.eks.outputs.cluster_name
  }
  security_group_selector_tags = {
    "karpenter.sh/discovery/${dependency.eks.outputs.cluster_name}" = dependency.eks.outputs.cluster_name
  }

  instance_categories  = local.env_vars.locals.eks.karpenter.instance_categories
  instance_cpus        = local.env_vars.locals.eks.karpenter.instance_cpus
  arch                 = local.env_vars.locals.eks.karpenter.arch
  # capacity_type       = local.env_vars.locals.eks.karpenter.capacity_type
  instance_generation  = local.env_vars.locals.eks.karpenter.instance_generation
  cpu_limit            = local.env_vars.locals.eks.karpenter.cpu_limit
  consolidation_policy = local.env_vars.locals.eks.karpenter.consolidation_policy
  consolidate_after    = local.env_vars.locals.eks.karpenter.consolidate_after
  common_sg_name       = local.env_vars.locals.vpc.common_sg_name

  aws_profile         = local.env_vars.locals.aws_profile
  region              = include.root.locals.region
  kube_host           = dependency.eks.outputs.cluster_endpoint
  kube_ca_certificate = dependency.eks.outputs.cluster_certificate_authority_data
  cluster_name        = dependency.eks.outputs.cluster_name
}