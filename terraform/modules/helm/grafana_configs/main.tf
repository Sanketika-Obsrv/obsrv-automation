resource "helm_release" "grafana_configs" {
    name             = var.grafana_configs_release_name
    chart            = "${path.module}/${var.grafana_configs_chart_path}"
    namespace        = var.grafana_configs_namespace
    create_namespace = var.grafana_configs_create_namespace
    wait_for_jobs    = var.grafana_configs_wait_for_jobs
    timeout          = var.grafana_configs_chart_install_timeout
    depends_on       = [var.grafana_configs_chart_depends_on]
    force_update     = true
    cleanup_on_fail  = true
    atomic           = true
}