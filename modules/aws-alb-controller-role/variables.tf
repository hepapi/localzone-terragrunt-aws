variable "oidc_provider_arn" {
  type        = string
  description = "The arn of oidc provider"
}
variable "kube_host" {}
variable "kube_ca_certificate" {}
variable "aws_profile" {}

variable "region" {
  type        = string
  description = "Custom values for the Helm release in YAML format"
}

variable "cluster_name" {
  description = "EKS Cluster name"
  type        = string
}