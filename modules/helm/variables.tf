variable "name" {
  type        = string
  description = "The name of the ArgoCD Helm release"
}

variable "namespace" {
  type        = string
  description = "The namespace in which to deploy ArgoCD"
  default     = "argocd"
}

variable "helm_repo_url" {
  type        = string
  description = "The Helm repository URL for ArgoCD"
  default     = "https://argoproj.github.io/argo-helm"
}

variable "chart_name" {
  type        = string
  description = "The name of the Helm chart"
  default     = "argo-cd"
}

variable "chart_version" {
  type        = string
  description = "The version of the Helm chart"
  default     = "5.32.0"
}

variable "values" {
  type        = string
  description = "Custom values for the Helm release in YAML format"
  default     = ""
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