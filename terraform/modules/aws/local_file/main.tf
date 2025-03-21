resource "local_file" "global_cloud_values" {
  content  = templatefile(var.template_path, var.template_vars)
  filename = var.output_path
}
