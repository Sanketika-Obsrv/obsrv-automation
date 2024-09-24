resource "helm_release" "loki" {
    name             = var.loki_release_name
    repository       = var.loki_chart_repository
    chart            = var.loki_chart_name
    version          = var.loki_chart_version
    namespace        = var.loki_namespace
    create_namespace = var.loki_create_namespace
    wait_for_jobs    = var.loki_wait_for_jobs
    timeout          = var.loki_install_timeout
    force_update     = true
    cleanup_on_fail  = true
    atomic           = true
    values = [
      templatefile("${path.module}/${var.loki_custom_values_yaml}",
        {
          loki_auth_enabled                            = var.loki_auth_enabled
          minio_enabled                                = var.minio_enabled
          minio_service_monitor_enabled                = var.minio_service_monitor_enabled
          minio_include_node_metrics                   = var.minio_include_node_metrics
          loki_dashboards_namespace                    = var.loki_dashboards_namespace
          limits_config_enforce_metric_name            = var.limits_config_enforce_metric_name
          limits_config_reject_old_samples             = var.limits_config_reject_old_samples
          limits_config_reject_old_samples_max_age     = var.limits_config_reject_old_samples_max_age
          limits_config_max_cache_freshness_per_query  = var.limits_config_max_cache_freshness_per_query
          limits_config_split_queries_by_interval      = var.limits_config_split_queries_by_interval
          limits_config_retention_period               = var.limits_config_retention_period
          compactor_retention_enabled                  = var.compactor_retention_enabled
          compactor_working_directory                  = var.compactor_working_directory
        }
      )
    ]
}