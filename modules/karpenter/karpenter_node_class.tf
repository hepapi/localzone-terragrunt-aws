resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      kubelet:
        maxPods: ${var.maxPods}
      amiSelectorTerms:
      - alias: ${var.amiAlias}
      role: "${var.karpenter_node_iam_role_name}"
      blockDeviceMappings:
      - deviceName: /dev/xvda
        ebs:
          volumeSize: "${var.diskSize}Gi"
          volumeType: gp3
          encrypted: true
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery/${var.eks_cluster_name}: ${var.eks_cluster_name}
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery/${var.eks_cluster_name}: ${var.eks_cluster_name}
        - tags:
            Name: ${var.common_sg_name}
      tags:
        karpenter.sh/discovery/${var.eks_cluster_name}: ${var.eks_cluster_name}
        Name: "Karpenter-Node-${var.eks_cluster_name}"
      userData: |
        #!/bin/bash
        echo "Running custom user data script"
        sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
        sudo systemctl status amazon-ssm-agent
        
  YAML

}
