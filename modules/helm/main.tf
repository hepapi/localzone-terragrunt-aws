locals {
  release_name = var.name
}


resource "helm_release" "this" {
  name       = local.release_name
  namespace  = var.namespace
  repository = var.helm_repo_url
  chart      = var.chart_name
  version    = var.chart_version
  create_namespace = true
  values = [var.values]
  set    = var.sets
}

