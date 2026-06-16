output "release_name" {
  value       = helm_release.aws_ebs_csi_driver.name
  description = "Helm Release Name"
}
