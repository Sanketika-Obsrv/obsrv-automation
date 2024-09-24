resource "null_resource" "kubectl" {
  triggers = {
    command = "kubectl annotate storageclasses gp2 storageclass.kubernetes.io/is-default-class- && kubectl patch storageclasses gp2 -p '{\"allowVolumeExpansion\": true}'"
  }
  provisioner "local-exec" {
    command = "kubectl annotate storageclasses gp2 storageclass.kubernetes.io/is-default-class- && kubectl patch storageclasses gp2 -p '{\"allowVolumeExpansion\": true}'"
    interpreter = ["/bin/bash", "-c"]
  }
}

resource "helm_release" "eks_storage_class" {
    name             = var.eks_storage_class_release_name
    chart            = "${path.module}/${var.eks_storage_class_chart_path}"
    timeout          = var.eks_storage_class_install_timeout
    depends_on       = [null_resource.kubectl]
    cleanup_on_fail  = true
    atomic           = true
    values           = []
}