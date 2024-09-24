resource "helm_release" "monitoring" {
    name             = var.monitoring_release_name
    chart            = "${path.module}/${var.monitoring_chart_path}"
    version          = var.monitoring_chart_version
    namespace        = var.monitoring_namespace
    create_namespace = var.monitoring_create_namespace
    wait_for_jobs    = var.monitoring_wait_for_jobs
    timeout          = var.monitoring_install_timeout
    force_update     = false
    cleanup_on_fail  = true
    atomic           = true
    values = [
      templatefile("${path.module}/${var.monitoring_custom_values_yaml}",
        {
            prometheus_persistent_volume_size      = var.prometheus_persistent_volume_size
            prometheus_metrics_retention           = var.prometheus_metrics_retention
            gf_auth_generic_oauth_enabled          = var.monitoring_grafana_oauth_configs["gf_auth_generic_oauth_enabled"]
            gf_auth_generic_oauth_name             = var.monitoring_grafana_oauth_configs["gf_auth_generic_oauth_name"]
            gf_auth_generic_oauth_allow_sign_up    = var.monitoring_grafana_oauth_configs["gf_auth_generic_oauth_allow_sign_up"]
            gf_auth_generic_oauth_client_id        = var.monitoring_grafana_oauth_configs["gf_auth_generic_oauth_client_id"]
            gf_auth_generic_oauth_client_secret    = var.monitoring_grafana_oauth_configs["gf_auth_generic_oauth_client_secret"]
            gf_auth_generic_oauth_scopes           = var.monitoring_grafana_oauth_configs["gf_auth_generic_oauth_scopes"]
            gf_auth_generic_oauth_auth_url         = "https://${var.kong_ingress_domain}/console/api/oauth/v1/authorize"
            gf_auth_generic_oauth_token_url        = "https://${var.kong_ingress_domain}/console/api/oauth/v1/token"
            gf_auth_generic_oauth_api_url          = "https://${var.kong_ingress_domain}/console/api/oauth/v1/userinfo"
            gf_auth_generic_oauth_auth_http_method = var.monitoring_grafana_oauth_configs["gf_auth_generic_oauth_auth_http_method"]
            gf_auth_generic_oauth_username_field   = var.monitoring_grafana_oauth_configs["gf_auth_generic_oauth_username_field"]
            gf_security_allow_embedding            = var.monitoring_grafana_oauth_configs["gf_security_allow_embedding"]
            s3_backups_bucket                      = var.s3_backups_bucket
            velero_storage_bucket                  = var.velero_storage_bucket
            checkpoint_storage_bucket              = var.checkpoint_storage_bucket
            s3_bucket                              = var.s3_bucket
            backup_folder_prefixes                 = var.backup_folder_prefixes
            grafana_persistent_volume_size         = var.grafana_persistent_volume_size
            kong_ingress_domain                    = var.kong_ingress_domain
            grafana_ingress_path                   = var.grafana_ingress_path
            service_type                           = var.service_type
            smtp_enabled                           = var.smtp_enabled
            smtp_config                            = var.smtp_config

        }
      )
    ]
}