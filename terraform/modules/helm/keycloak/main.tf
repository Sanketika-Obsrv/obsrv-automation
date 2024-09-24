resource "helm_release" "keycloak" {
    name             = var.keycloak_release_name
    chart            = "${path.module}/${var.keycloak_chart_path}"
    namespace        = var.keycloak_namespace
    create_namespace = var.keycloak_create_namespace
    timeout          = var.keycloak_install_timeout
    depends_on       = [var.keycloak_chart_depends_on]
    force_update     = true
    cleanup_on_fail  = true
    atomic           = true
    values = [
      templatefile("${path.module}/${var.keycloak_custom_values_yaml}",
        {
          service_type                           = var.service_type
          kong_ingress_domain                    = "https://${var.kong_ingress_domain}"
          kong_proxy_keycloak                    = "auth.${var.kong_ingress_domain}"
          postgresql_service_name                = var.postgresql_service_name
        }
      )
    ]
}