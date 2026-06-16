variable "region" {
  type        = string
  default     = "eu-west-1"
}

variable "amiAlias" {
  type        = string
  default     = "al2@latest"
}

variable "diskSize" {
  type        = number
  default     = 50
}

variable "maxPods" {
  type        = number
  default     = 110
}


variable "karpenter_node_iam_role_name" {
  description = "The IAM role name for Karpenter nodes."
  type        = string
}

variable "eks_cluster_name" {
  description = "The name of the EKS cluster."
  type        = string
}


variable "instance_categories" {
  type    = list(string)
  default = ["c", "m", "r"]
}

variable "instance_cpus" {
  type    = list(string)
  default = ["4", "8", "16", "32"]
}

variable "arch" {
  type    = list(string)
  default = ["amd64"]
}

variable "capacity_type" {
  type    = list(string)
  default = ["spot"]
}

variable "instance_generation" {
  type    = string
  default = "2"
}

variable "cpu_limit" {
  type    = number
  default = 100
}

variable "consolidation_policy" {
  type    = string
  default = "WhenEmpty"
}

variable "consolidate_after" {
  type    = string
  default = "30s"
}

variable "ami_family" {
  type    = string
  default = "AL2023"
}

variable "common_sg_name" {
  type    = string
  default = "common-sg"
}
