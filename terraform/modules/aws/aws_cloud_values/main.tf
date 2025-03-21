# This resource is used to replace the contents of global-cloud-values-aws.yaml

resource "null_resource" "global_cloud_values" {
  provisioner "local-exec" {
    command = <<EOT
      printf '%s' '${templatefile(var.template_path, var.template_vars)}' > "${var.output_path}"
    EOT
  }

  triggers = {
    always_run = timestamp()
  }
}