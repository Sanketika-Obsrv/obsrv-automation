resource "local_file" "global_values_yaml" {
  content  = templatefile("${path.module}/global-values.yaml.tfpl", {
    private_key = var.private_key
    public_key = var.public_key
  })
  filename = var.file_path
}

output "global_values_file_path" {
  description = "Path to the generated global-values.yaml.tfpl file"
  value       = local_file.global_values_yaml.filename
}
