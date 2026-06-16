locals {
  region = "eu-central-1"
  env = basename(get_terragrunt_dir())
  aws_profile = "hepapi-sso"

  not_create = {
    kms = true
    bastion = true
    fargate = true
    ingress-nginx = true
    internal-ingress-nginx = true
    aurora = true
    postgresql = true
    elasticache = true
    documentdb= true
    waf = true
  }
  module_versions = {
    vpc = "5.19.0"
    vpn-gateway = "4.0.0"
    acm = "5.1.1"
    kms = "3.1.1"
    elasticache = "1.4.1"
    eks = "20.33.1"
    iam_attach_efs_role = "5.52.2"     #### iam_iam-role-for-service-accounts-eks module
    iam_attach_ebs_role = "5.52.2"
    fargate = "20.33.1"
    nginx-ingress-chart = "2.0.1"
    karpenter-module = "20.33.1"
    efs = "1.6.5"
    documentdb = "0.27.0"
    aurora     = "9.11.0"
    rds        = "6.10.0"
    security-group = "5.3.0"
    ec2 = "5.7.1"
    keypair = "2.0.3"
    s3 = "4.5.0"
    node-group = "20.33.1"
  }

  helm_versions = {
    efs-csi-chart       = "3.1.5"
    ebs-csi-chart       = "2.40.3"
    argocd-chart        = "7.8.13"
    argocd-app-chart    = "2.0.2"
    nginx-ingress-chart = "2.0.1"
    karpenter-chart     = "1.1.2"
    aws-load-balancer-controller = "1.11.0"
  }

  vpc = {
    vpc_name = "hepapi-local-zone"
    private_subnets = ["10.20.0.0/19", "10.20.64.0/19", "10.20.32.0/19"]
    public_subnets  = ["10.20.100.0/24", "10.20.102.0/24", "10.20.101.0/24"]
    cidr = "10.20.0.0/16"
    azs  = ["eu-central-1a", "eu-central-1b", "eu-central-1-ist-1a"]
    enable_nat_gateway     = true
    enable_vpn_gateway     = false
    single_nat_gateway     = true
    one_nat_gateway_per_az = false
    common_sg_name = "hepapi-local-zone-common-sg"
  }

 
    eks = {
    cluster_version = "1.35"
    cluster_name = "hepapi-local-zone-eks"
    authentication_mode = "API"
    cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]
    create_iam_role              = true
    enable_irsa                  = true
    attach_cluster_encryption_policy = true
    cluster_endpoint_private_access = true
    cluster_endpoint_public_access  = true
    cluster_service_ipv4_cidr = "10.240.0.0/16"
    enable_cluster_creator_admin_permissions = false
    enable_cluster_compute_config = false
    support_type = "STANDARD" 
    create_iam_efs = "eks-hepapi-local-zone-efs-cs"
    create_iam_ebs = "eks-hepapi-local-zone-ebs-cs"
    policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
    fargate_name = "karpenter"
    kms_key_aliases = ["eks-hepapi-local-zone-custom"]
    cluster_addons = {
      vpc-cni_addon_version = "v1.21.1-eksbuild.1"
      coredns_addon_version = "v1.13.2-eksbuild.3"
    }

    kms_key_administrators = [
    "arn:aws:iam::xxxxxxxxxxxx:root",
  ]
    access_entries = {
      
      hepapi = {
        kubernetes_groups = []
        principal_arn     = "arn:aws:iam::xxxxxxxxxxxx:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdministratorAccess_xxxxxxxxxxxx"
        policy_associations = {
          policy = {
            policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
            access_scope = {
              type = "cluster"
            }
          }
        }
      }
    }

    karpenter = {
      amiAlias                    = "al2023@latest"
      diskSize                    = 80
      maxPods                     = 55
      instance_categories         = ["c", "m", "r"]
      instance_cpus               = ["4", "8", "16"]
      arch                        = ["amd64"]
      instance_generation         = "6"
      cpu_limit                   = 50
      consolidation_policy        = "WhenEmptyOrUnderutilized"
      consolidate_after           = "60s"
      replicas                    = "1"
    }

  }

  node_groups = {
    name             = "hepapi-istanbul-node-group"
    desired_size     = 1
    min_size         = 1
    max_size         = 2
    instance_types   = ["m7i.xlarge"]
    capacity_type    = "ON_DEMAND"
    disk_size        = 80
    cluster_service_cidr = "10.240.0.0/16"
    iam_role_name        = "hepapi-istanbul-node-group"
    launch_template_name = "hepapi-istanbul"
    update_config = {
      max_unavailable = 1
    }
    labels = {
      topology = "local-zone"
      zone     = "istanbul"
    }
  }


}