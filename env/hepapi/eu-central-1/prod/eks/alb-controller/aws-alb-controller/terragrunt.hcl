terraform {
  source = find_in_parent_folders("../../../modules/helm")
}

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

dependencies {
  paths = [find_in_parent_folders("aws-alb-controller-role")]
}

dependency "eks" {
  config_path = find_in_parent_folders("eks")
  mock_outputs = {
    cluster_endpoint                   = "https://1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A.gr7.eu-west-1.eks.amazonaws.com"
    cluster_certificate_authority_data = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURCVENDQWUyZ0F3SUJBZ0lJZldsSDhlTytUbzB3RFFZSktvWklodmNOQVFFTEJRQXdGVEVUTUJFR0ExVUUKQXhNS2EzVmlaWEp1WlhSbGN6QWVGdzB5TkRFd01UQXdPVEkzTkRsYUZ3MHpOREV3TURnd09UTXlORGxhTUJVeApFekFSQmdOVkJBTVRDbXQxWW1WeWJtVjBaWE13Z2dFaU1BMEdDU3FHU0liM0RRRUJBUVVBQTRJQkR3QXdnZ0VLCkFvSUJBUUN6VkVZdGZmR1ZDK3FUclBQRzZUc3JJQVVUdWp2dElFU0JnUDBqNENMbWg0VjFDU0tDOWs2SzRRdCsKNkl5SUVmSHk3aDhieEhnUi9rWEJ2eUdKNEt2MU9SUjQ2cCtwa29RY21nR2c3eHFXODdDS0RYTmhUTkJ0Q0JrYgpBV1lETnlSZEdmQUFxd2x6aVY3R2FYdmJTTkVVWit2YlY1WFBzeXIyWjhRTGRRUUFkZDgyajgvTFJlSDd1Mi9sCm1HU24yN09TZUVPdHQzSUJGUW51aHEyVkoxcjUzT1NhaVRuOFJwNTk5M2QzRTBUNkV3Vm5BclkzcTNEN2JhMFkKWmpjd3AzdE1TSWpLb21FMTZ3d0g0b2lGbUNkZGRkUDRpalI0K1VBdUN0TXRlajVOcVFJVUtITi9KblVIV1dxLwpLaStPb0Fra01ZTDNHL1ZTVnVMVzNUNVZwald0QWdNQkFBR2pXVEJYTUE0R0ExVWREd0VCL3dRRUF3SUNwREFQCkJnTlZIUk1CQWY4RUJUQURBUUgvTUIwR0ExVWREZ1FXQkJSeWU3L1RZbDRCZDUydUVMT3JnMFdUWWlBNUd6QVYKQmdOVkhSRUVEakFNZ2dwcmRXSmxjbTVsZEdWek1BMEdDU3FHU0liM0RRRUJDd1VBQTRJQkFRQ1QyTFNGREFEMgp2QWIySlFKVlF2WkErU0g5dGRJY0xTK3ZXM0N5aGhaMVVObXZqWXl5R00waDQ3Y1VvcDZtb0lhS0JxRnpPc1ZhCjVZdmpBWFBmazQvejNlR3F2aVRnZGxaK1o3K3VvTzYvYy9aU1prSU9TOTVaT01VdElvVTZPaEpVa2h5bUtydmEKVlFvQ0NVZXpSUUY2eGlrQktndlp2dURkbE9iU0FZanpEWHhKSGduMjhqRHRhTnd3MXBudHhSR2hxSWYrRzlxcwpUQWpXL21ENTgzbWFkZHlnSVZUbVN3d1ZoRzkxV0RzSkYySXNxcGJaRm5WRFZxZksrTzZ6NlM0ck41QmVKOFhnCjJUdis4VG1NV1RCZm5GZ1NLN2FlUmFDbFlyMkx4NG1xV2dkVGY2WVJISmdXcHlFamZ6emxUZ3E4T21WQk5UdVYKOHVQRjl5eVBqdm1YCi0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K"
    cluster_name                       = "demo-cluster"
  }
}

dependency "vpc" {
  config_path = "${find_in_parent_folders("vpc")}"
  mock_outputs = {
    vpc_id          = "vpc-123456"
    private_subnets = ["subnet-1234", "subnet-4321"]
  }
}

inputs = {
  name                = "aws-load-balancer-controller"
  namespace           = "kube-system"
  aws_profile         = local.env_vars.locals.aws_profile
  region              = include.root.locals.region
  chart_version       = local.env_vars.locals.helm_versions.aws-load-balancer-controller
  chart_name          = "aws-load-balancer-controller"
  helm_repo_url       = "https://aws.github.io/eks-charts"
  kube_host           = dependency.eks.outputs.cluster_endpoint
  kube_ca_certificate = dependency.eks.outputs.cluster_certificate_authority_data
  cluster_name        = dependency.eks.outputs.cluster_name


  sets = [
    {
      name  = "serviceAccount.create"
      value = "false"
    },
    {
      name  = "vpcId"
      value = dependency.vpc.outputs.vpc_id
    },

    {
      name  = "clusterName"
      value = dependency.eks.outputs.cluster_name
    },
    {
     name  = "serviceAccount.name"
     value = "aws-load-balancer-controller"
    },
    {
     name  = "image.repository"
     value = "602401143452.dkr.ecr.eu-central-1.amazonaws.com/amazon/aws-load-balancer-controller"
    }
  ]
}