resource "local_file" "global_cloud_values_yaml" {
  content  = templatefile("${path.module}/global-cloud-values.yaml.tfpl", {
    private_key = var.private_key
    public_key = var.public_key
  })
  filename = var.file_path
}

output "global_values_cloud_file_path" {
  description = "Path to the generated global-cloud-values.yaml file"
  value       = local_file.global_cloud_values_yaml.filename
}
