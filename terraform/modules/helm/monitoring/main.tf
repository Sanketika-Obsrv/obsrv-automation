resource "helm_release" "monitoring" {
    name             = var.monitoring_release_name
    repository       = var.monitoring_chart_repository
    chart            = var.monitoring_chart_name
    version          = var.monitoring_chart_version
    namespace        = var.monitoring_namespace
    create_namespace = var.monitoring_create_namespace
    wait_for_jobs    = var.monitoring_wait_for_jobs
    timeout          = var.monitoring_install_timeout
    force_update     = true
    cleanup_on_fail  = true
    atomic           = true
    values = [
      templatefile("${path.module}/${var.monitoring_custom_values_yaml}",
        {
            prometheus_persistent_volume_size = var.prometheus_persistent_volume_size
            prometheus_metrics_retention      = var.prometheus_metrics_retention
        }
      )
    ]
}