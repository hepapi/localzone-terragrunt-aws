resource "kubectl_manifest" "karpenter_node_pool_spot" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: hepapi-istanbul
      labels:
        capacity-type: on-demand
    spec:
      template:
        metadata:
          labels:
            capacity-type: on-demand
            topology: local-zone
            zone: istanbul
        spec:
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: default
          requirements:
            - key: "karpenter.k8s.aws/instance-category"
              operator: In
              values: ${jsonencode(var.instance_categories)}
            - key: "karpenter.k8s.aws/instance-cpu"
              operator: In
              values: ${jsonencode(var.instance_cpus)}
            - key: "karpenter.k8s.aws/instance-generation"
              operator: Gt
              values: ["${var.instance_generation}"]
            - key: "kubernetes.io/arch"
              operator: In
              values: ${jsonencode(var.arch)}
            - key: "karpenter.sh/capacity-type"
              operator: In
              values: ["on-demand"]
            - key: "topology.kubernetes.io/zone"
              operator: In
              values: ["eu-central-1-ist-1a"]
      limits:
        cpu: ${var.cpu_limit}
      disruption:
        consolidationPolicy: ${var.consolidation_policy}
        consolidateAfter: ${var.consolidate_after}
  YAML
}
