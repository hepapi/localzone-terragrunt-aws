resource "helm_release" "aws_ebs_csi_driver" {
  name       = "aws-ebs-csi-driver"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver/"
  chart      = "aws-ebs-csi-driver"
  version    = var.chart_version
  verify    = false

  set = [
    {
      name  = "controller.serviceAccount.create"
      value = "true"
    },
    {
      name  = "controller.serviceAccount.name"
      value = "ebs-csi-controller-sa"
    },
    {
      name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = var.ebs_csi_role_arn
    },
  ]
}

resource "kubectl_manifest" "storageclassname" {
  yaml_body = <<-YAML
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: ${var.storageclassname}
      annotations:
        # storageclass.kubernetes.io/is-default-class: "true"
    provisioner: ebs.csi.aws.com
    parameters:
      tagSpecification_1: "Name={{ .PVCNamespace }}-{{ .PVCName }}"
      tagSpecification_2: "Namespace={{ .PVCNamespace }}"
    allowVolumeExpansion: true
    volumeBindingMode: WaitForFirstConsumer
  YAML
}