# output "release_name" {
#   value       = helm_release.this.name
#   description = "Helm Release Name"
# }

# output "karpenter_node_class_name" {
#   description = "The name of the Karpenter EC2NodeClass."
#   value       = kubectl_manifest.karpenter_node_class.metadata[0].name
# }

# output "karpenter_node_pool_name" {
#   description = "The name of the Karpenter NodePool."
#   value       = kubectl_manifest.karpenter_node_pool.metadata[0].name
# }
