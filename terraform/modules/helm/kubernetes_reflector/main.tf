resource "helm_release" "kubernetes_reflector" {
    name             = var.kubernetes_reflector_release_name
    repository       = var.kubernetes_reflector_chart_repository
    chart            = var.kubernetes_reflector_chart_name
    version          = var.kubernetes_reflector_chart_version
    namespace        = var.kubernetes_reflector_namespace
    create_namespace = var.kubernetes_reflector_create_namespace
    wait_for_jobs    = var.kubernetes_reflector_wait_for_jobs
    timeout          = var.kubernetes_reflector_install_timeout
    force_update     = true
    cleanup_on_fail  = true
    atomic           = true
    values = [
      templatefile("${path.module}/${var.kubernetes_reflector_custom_values_yaml}",
      {}
      )
    ]
}

# resource "helm_release" "docker_registry_secret" {
# name             = var.docker_registry_secret_release_name
# chart            = "${path.module}/${var.docker_registry_secret_chart_path}"
# namespace        = var.kubernetes_reflector_namespace
# wait_for_jobs    = var.kubernetes_reflector_wait_for_jobs
# timeout          = var.kubernetes_reflector_install_timeout
# depends_on       = [helm_release.kubernetes_reflector]
# force_update     = true
# cleanup_on_fail  = true
# atomic           = true
# values = [
# templatefile("${path.module}/${var.docker_registry_secret_custom_values_yaml}",
# {
#         docker_registry_secret_namespace          = var.kubernetes_reflector_namespace
# docker_registry_secret_dockerconfigjson   = var.docker_registry_secret_dockerconfigjson
# docker_registry_secret_allowed_namespaces = var.docker_registry_secret_allowed_namespaces
# docker_registry_secret_name               = var.docker_registry_secret_name
# }
#     )
#   ]
# }