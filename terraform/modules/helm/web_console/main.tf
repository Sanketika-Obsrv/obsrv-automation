resource "helm_release" "web_console" {
    name             = var.web_console_release_name
    chart            = "${path.module}/${var.web_console_chart_path}"
    namespace        = var.web_console_namespace
    create_namespace = var.web_console_create_namespace
    depends_on       = [var.web_console_chart_depends_on]
    force_update     = true
    cleanup_on_fail  = true
    atomic           = true
    values = [
      templatefile("${path.module}/${var.web_console_custom_values_yaml}",
        {
          env                                = var.env
          web_console_namespace              = var.web_console_namespace
          web_console_image_repository       = var.web_console_image_repository
          web_console_image_name             = var.web_console_image_name
          web_console_image_tag              = var.web_console_image_tag
          port                               = var.web_console_configs["port"]
          app_name                           = var.web_console_configs["app_name"]
          prometheus_url                     = var.web_console_configs["prometheus_url"]
          react_app_grafana_url              = var.web_console_configs["react_app_grafana_url"]
          react_app_superset_url             = var.web_console_configs["react_app_superset_url"]          
          https                              = var.web_console_configs["https"]
          react_app_version                  = var.web_console_configs["react_app_version"]
          generate_sourcemap                 = var.web_console_configs["generate_sourcemap"]
        }
      )
    ]
}
