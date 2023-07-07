resource "null_resource" "get_kubeconfig" {
  triggers = {
    command = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = "aws eks --region us-east-2 update-kubeconfig --name ${var.building_block}-${var.env}-eks"
    interpreter = ["/bin/bash", "-c"]
  }
}