terraform {
  source = find_in_parent_folders("../../../modules/ebs-csi")
}

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

dependency "eks" {
  config_path = find_in_parent_folders("eks")
  mock_outputs = {
    cluster_endpoint                   = "https://1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A.gr7.eu-west-1.eks.amazonaws.com"
    cluster_certificate_authority_data = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURCVENDQWUyZ0F3SUJBZ0lJV24rTVZ4NWM3NDh3RFFZSktvWklodmNOQVFFTEJRQXdGVEVUTUJFR0ExVUUKQXhNS2EzVmlaWEp1WlhSbGN6QWVGdzB5TkRFeE1EWXdOekkzTXpGYUZ3MHpOREV4TURRd056TXlNekZhTUJVeApFekFSQmdOVkJBTVRDbXQxWW1WeWJtVjBaWE13Z2dFaU1BMEdDU3FHU0liM0RRRUJBUVVBQTRJQkR3QXdnZ0VLCkFvSUJBUURQR0FPWlpNUTdTdGZMTGtmQlpMSFNSYmE2VXFoeUJBY1RXNTRhbHUxS1JEZUpEV3N4aFJQUlUza3MKb2YzY1NkcWo4WWFTRUJmTHByd3hqeUF6ZHZoL1ZmRnhQRWlxeGRSMXBkVm95VTBWY201U05qWU10RzczT01megpnTUtva3Rlb253N3NSODFrMXVER1U1NVJNakhnOTExME4xejBaZWZUbHhCbGIwbG9hNHNra04wRmJYVTZ6MVg3CkdRTzVYa1J1K0ZIS1UwVWJoNytIaEN5V3BGeTlqWkFLbExiOGpWRnQyK1hSbHRFMjh2QlBiZm9IRkIxckhKRmoKN2tIdDJXRmdmUUZYZ21HOVhiekZDOE0wc2ZqNnViOUl2dkxKL2czRHEyc3dhQnFTZDFZanlybGlwSDhuc0VQbgpBVmJ0RU1oQlFhVHJyZU1CQ3VzTDAyQkk1K2VwQWdNQkFBR2pXVEJYTUE0R0ExVWREd0VCL3dRRUF3SUNwREFQCkJnTlZIUk1CQWY4RUJUQURBUUgvTUIwR0ExVWREZ1FXQkJTNUFCR3d4cGVzMDcvS1lna0hyNllDakpOYkxUQVYKQmdOVkhSRUVEakFNZ2dwcmRXSmxjbTVsZEdWek1BMEdDU3FHU0liM0RRRUJDd1VBQTRJQkFRQk1WOE1DWXBhTwpQb0haL0FZWnA5S0tzLzhlNXg1dkMwUVU0NHdmSkMxcDgxZmZ6MC9nMzJtVndKem4venZ2WkxrT1ZmKzN2WlVGCnQ3dDhaVzdqNlZyVi9LeUw1allyaE1CZWl4empjMGZCRFQySzFGdUF5YlNJT0gwNlhLN3pPT3NEdUhQYXAxUm8KNzI3eGUycndxajd0TGt5VzVOZWp1MlVacUVySFZZYUZFS3Vhc2g3OWswREc1WUhORkQzWHZ0WGxrUXBiRmdJZwpmU1NoOGQzbFEwYUZvSU9SMDBrMytJUHljUU5vQ1R0MEIycWNTRkRsSXlxcHNzSXBYeXdJQmlVNXpyYUxFcG9ICjJITkdmdEgzVjR5bDFaUXR1aFU1WE1TZmh4b1RtdUtGdjdiVmtFOExzVzBWV0UxcnpFbXY0QkVUSmNiMlFqSSsKMFJ3N2JoVUdLalF2Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K"
    cluster_name                       = "demo-cluster"
    oidc_provider                      = "arn:aws:iam::1111111111:oidc-provider/oidc.eks.eu-west-1.amazonaws.com/id/AB12"
    oidc_provider_arn                  = "arn:aws:iam::111111111111:oidc-provider/oidc.eks.eu-west-1.amazonaws.com/id/AB12"
  }
}


dependency "ebs-csi-role-arn" {
  config_path = find_in_parent_folders("iam/attach_ebs_csi_role")
  mock_outputs = {
    iam_role_arn = "arn:aws:iam::111111111111:oidc-provider/oidc.eks.eu-west-1.amazonaws.com/id/AB12"
  }
}

inputs = {
  aws_profile         = local.env_vars.locals.aws_profile
  region              = include.root.locals.region
  kube_host           = dependency.eks.outputs.cluster_endpoint
  kube_ca_certificate = dependency.eks.outputs.cluster_certificate_authority_data
  cluster_name        = dependency.eks.outputs.cluster_name
  storageclassname    = "hepapi-local-zone-ebs-sc"
  account_id          = include.root.locals.aws_account_id
  ebs_csi_role_arn    = dependency.ebs-csi-role-arn.outputs.iam_role_arn
  chart_version       = local.env_vars.locals.helm_versions.ebs-csi-chart

}


