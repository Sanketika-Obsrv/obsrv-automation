resource "helm_release" "docker_registry_secret" {
    name             = "web-console-docker-secret"
    chart            = "${path.module}/docker-registry-secret-helm-chart"
    namespace        = var.web_console_namespace
    create_namespace = var.web_console_create_namespace
    depends_on       = [var.web_console_chart_depends_on]
    timeout          = var.web_console_install_timeout
    force_update     = true
    cleanup_on_fail  = true
    atomic           = true
    values = [
    templatefile("${path.module}/docker_registry_secrets.yaml.tfpl",
    {
        docker_registry_secret_dockerconfigjson     = var.docker_registry_secret_dockerconfigjson,
        docker_registry_secret_name                 = var.docker_registry_secret_name
    })
  ]
}

resource "helm_release" "web_console" {
    name             = var.web_console_release_name
    chart            = "${path.module}/${var.web_console_chart_path}"
    namespace        = var.web_console_namespace
    create_namespace = var.web_console_create_namespace
    depends_on       = [var.web_console_chart_depends_on]
    timeout          = var.web_console_install_timeout
    force_update     = true
    cleanup_on_fail  = true
    atomic           = true
    values = [
      templatefile("${path.module}/${var.web_console_custom_values_yaml}",
        {
          env                                = var.env
          web_console_namespace              = var.web_console_namespace
          web_console_image_repository       = var.web_console_image_repository
          web_console_image_tag              = var.web_console_image_tag
          docker_registry_secret_name        = var.docker_registry_secret_name
          grafana_secret_name                = var.grafana_secret_name
          service_account_name               = var.grafana_service_account_name
          port                               = var.web_console_configs["port"]
          app_name                           = var.web_console_configs["app_name"]
          prometheus_url                     = var.web_console_configs["prometheus_url"]
          config_api_url                     = var.web_console_configs["config_api_url"]
          obs_api_url                        = var.web_console_configs["obs_api_url"]
          system_api_url                     = var.web_console_configs["system_api_url"]
          alert_manager_url                  = var.web_console_configs["alert_manager_url"]
          grafana_url                        = "https://${var.kong_ingress_domain}/grafana"
          superset_url                       = "https://${var.kong_ingress_domain}"
          react_app_grafana_url              = "https://${var.kong_ingress_domain}/grafana"
          react_app_superset_url             = "https://${var.kong_ingress_domain}"
          session_secret                     = var.web_console_configs["session_secret"]
          postgres_connection_string         = var.web_console_configs["postgres_connection_string"]
          oauth_web_console_url              = "https://${var.kong_ingress_domain}/console"
          auth_keycloak_realm                = var.web_console_configs["auth_keycloak_realm"]
          auth_keycloak_public_client        = var.web_console_configs["auth_keycloak_public_client"]
          auth_keycloak_ssl_required         = var.web_console_configs["auth_keycloak_ssl_required"]
          auth_keycloak_client_id            = var.web_console_configs["auth_keycloak_client_id"]
          auth_keycloak_client_secret        = var.web_console_configs["auth_keycloak_client_secret"]
          auth_keycloak_server_url           = var.web_console_configs["auth_keycloak_server_url"]
          auth_google_client_id              = var.web_console_configs["auth_google_client_id"]
          auth_google_client_secret          = var.web_console_configs["auth_google_client_secret"]
          https                              = var.web_console_configs["https"]
          react_app_version                  = var.web_console_configs["react_app_version"]
          generate_sourcemap                 = var.web_console_configs["generate_sourcemap"]
          auth_ad_url                        = var.web_console_configs["auth_ad_url"]
          auth_ad_user_name                  = var.web_console_configs["auth_ad_user_name"]
          auth_ad_base_dn                    = var.web_console_configs["auth_ad_base_dn"]
          auth_ad_password                   = var.web_console_configs["auth_ad_password"]
          react_app_authentication_allowed_types = var.web_console_configs["react_app_authentication_allowed_types"]
          auth_oidc_issuer                   = var.web_console_configs["auth_oidc_issuer"]
          auth_oidc_authrization_url         = var.web_console_configs["auth_oidc_authrization_url"]
          auth_oidc_token_url                = var.web_console_configs["auth_oidc_token_url"]
          auth_oidc_user_info_url            = var.web_console_configs["auth_oidc_user_info_url"]
          auth_oidc_client_id                = var.web_console_configs["auth_oidc_client_id"]
          auth_oidc_client_secret            = var.web_console_configs["auth_oidc_client_secret"]
          auth_token                         = var.web_console_configs["auth_token"]
          grafana_secret_allowed_namespaces  = var.grafana_secret_allowed_namespaces
          service_type                       = var.service_type
        }
      )
    ]
}