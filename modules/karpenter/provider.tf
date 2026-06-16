variable "kube_host" {}
variable "kube_ca_certificate" {}
variable "cluster_name" {}
variable "aws_profile" {}

provider "kubectl" {
  apply_retry_count      = 5
  host                   = var.kube_host
  cluster_ca_certificate = base64decode(var.kube_ca_certificate)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.region , "--profile", var.aws_profile ]
    
  }
}