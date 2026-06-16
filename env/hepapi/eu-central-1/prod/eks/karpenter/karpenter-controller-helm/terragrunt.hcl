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
    queue_name      = "demo-queue"
    service_account = "demo-serviceaccount"
    iam_role_arn    = "arn:aws:iam::111111111111:role/KarpenterController-11111111111111111111"
  }
}

inputs = {
  name                = "karpenter"
  namespace           = "kube-system"
  aws_profile         = local.env_vars.locals.aws_profile
  region              = include.root.locals.region
  chart_version       = local.env_vars.locals.helm_versions.karpenter-chart
  chart_name          = "karpenter"
  helm_repo_url       = "oci://public.ecr.aws/karpenter"
  kube_host           = dependency.eks.outputs.cluster_endpoint
  kube_ca_certificate = dependency.eks.outputs.cluster_certificate_authority_data
  cluster_name        = dependency.eks.outputs.cluster_name


  sets = [
    {
      name  = "serviceAccount.name"
      value = dependency.karpenter-module.outputs.service_account
    },
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = dependency.karpenter-module.outputs.iam_role_arn
    },

    {
      name  = "settings.interruptionQueue"
      value = dependency.karpenter-module.outputs.queue_name
    },
    {
      name  = "settings.clusterName"
      value = dependency.eks.outputs.cluster_name
    },
    {
      name  = "settings.clusterEndpoint"
      value = dependency.eks.outputs.cluster_endpoint
    },
    {
      name  = "replicas"
      value = local.env_vars.locals.eks.karpenter.replicas
    }
  ]
}