resource "helm_release" "promtail" {
    name             = var.promtail_release_name
    repository       = var.promtail_chart_repository
    chart            = var.promtail_chart_name
    version          = var.promtail_chart_version
    namespace        = var.promtail_namespace
    create_namespace = var.promtail_create_namespace
    wait_for_jobs    = var.promtail_wait_for_jobs
    timeout          = var.promtail_install_timeout
    depends_on       = [var.promtail_chart_depends_on]
    force_update     = true
    cleanup_on_fail  = true
    atomic           = true
    values = [
      templatefile("${path.module}/${var.promtail_custom_values_yaml}",
        {
          promtail_service_monitor_status  = var.promtail_service_monitor_status
        }
      )
    ]
}