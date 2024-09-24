resource "helm_release" "superset" {
    name             = var.superset_release_name
    chart            = "${path.module}/${var.superset_chart_path}"
    namespace        = var.superset_namespace
    create_namespace = var.superset_create_namespace
    wait_for_jobs    = var.superset_wait_for_jobs
    timeout          = var.superset_install_timeout
    depends_on       = [var.superset_chart_depends_on]
    force_update     = true
    cleanup_on_fail  = true
    atomic           = true
    values           = [
      templatefile("${path.module}/${var.superset_custom_values_yaml}",
      {
        pg_admin_username                     = var.postgresql_admin_username
        pg_admin_password                     = var.postgresql_admin_password
        pg_superset_user_password             = var.postgresql_superset_user_password
        superset_release_name                 = var.superset_release_name
        superset_namespace                    = var.superset_namespace
        superset_image_tag                    = var.superset_image_tag
        redis_namespace                       = var.redis_namespace
        redis_release_name                    = var.redis_release_name
        postgresql_service_name               = var.postgresql_service_name
        web_console_base_url                  = "https://${var.web_console_base_url}"
        superset_base_url                     = "https://${var.superset_base_url}"
        keycloak_base_url                     = "https://auth.${var.keycloak_base_url}"
        superset_oauth_clientid               = var.oauth_configs["superset_oauth_clientid"]
        superset_oauth_client_secret          = var.oauth_configs["superset_oauth_client_secret"]
        keycloak_oauth_client_secret          = var.oauth_configs["keycloak_oauth_client_secret"]
        superset_oauth_token                  = var.oauth_configs["superset_oauth_token"]
        dataset_api_namespace                 = var.dataset_api_namespace
        service_type                          = var.service_type
        redirection_auth_path                 = var.redirection_auth_path
      })
    ]
}