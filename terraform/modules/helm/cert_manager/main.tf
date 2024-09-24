resource "helm_release" "cert_manager" {
    name             = var.cert_manager_release_name
    repository       = var.cert_manager_chart_repository
    chart            = var.cert_manager_chart_name
    version          = var.cert_manager_chart_version
    namespace        = var.cert_manager_namespace
    create_namespace = var.cert_manager_create_namespace
    wait_for_jobs    = var.cert_manager_wait_for_jobs
    timeout          = var.cert_manager_install_timeout
    force_update     = true
    cleanup_on_fail  = true
    atomic           = true
    disable_webhooks = true
    values           = [file("${path.module}/${var.cert_manager_custom_values_yaml}")]
}