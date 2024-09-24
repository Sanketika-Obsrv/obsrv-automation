resource "helm_release" "kong_ingress_routes" {
    name             = var.kong_ingress_routes_release_name
    chart            = "${path.module}/${var.kong_ingress_routes_chart_path}"
    namespace        = var.kong_ingress_routes_namespace
    create_namespace = var.kong_ingress_routes_create_namespace
    timeout          = var.kong_ingress_routes_install_timeout
    cleanup_on_fail  = true
    atomic           = true
    values = [
      templatefile("${path.module}/${var.kong_ingress_routes_custom_values_yaml}",
        {
          kong_ingress_routes_namespace = var.kong_ingress_routes_namespace
          kong_ingress_domain           = var.kong_ingress_domain
        }
      )
    ]
}