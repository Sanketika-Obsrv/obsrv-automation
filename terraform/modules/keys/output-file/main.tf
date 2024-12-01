resource "local_file" "global_key_values_yaml" {
  content  = templatefile("${path.module}/global-key-values.yaml.tfpl.tfpl", {
    private_key = var.private_key
    public_key = var.public_key
  })
  filename = var.file_path
}

output "global_values_key_file_path" {
  description = "Path to the generated global-key-values.yaml.tfpl file"
  value       = local_file.global_key_values_yaml.filename
}
