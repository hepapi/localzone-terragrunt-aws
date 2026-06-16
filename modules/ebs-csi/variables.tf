variable "chart_version" {
  type        = string
  description = "The version of the Helm chart"
  default     = "2.40.3"
}

variable "values" {
  type        = string
  description = "Custom values for the Helm release in YAML format"
  default     = ""
}

variable "ebs_csi_role_arn" {
  type        = string
}


variable "region" {
  type        = string
  description = "Custom values for the Helm release in YAML format"
  default     = "eu-west-1"
}

variable "sets" {
  description = "A list of --set values to pass to Helm"
  type        = list(object({
    name  = string
    value = string
  }))
  default     = []
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}



variable "cluster_name" {
  description = "EKS Cluster name"
  type        = string
}

variable "storageclassname" {
  type        = string
  default     = "ebs-sc"
}

variable "kube_host" {}
variable "kube_ca_certificate" {}
variable "aws_profile" {}