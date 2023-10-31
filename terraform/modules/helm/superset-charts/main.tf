resource "helm_release" "superset_charts" {
    name             = var.superset_charts_release_name
    chart            = "${path.module}/${var.superset_charts_chart_path}"
    namespace        = var.superset_charts_namespace
    create_namespace = var.superset_charts_create_namespace
    depends_on       = [var.superset_charts_depends_on]
    wait_for_jobs    = var.superset_charts_wait_for_jobs
    timeout          = var.superset_charts_chart_install_timeout
    force_update     = true
    cleanup_on_fail  = true
    atomic           = true
    values = [
      templatefile("${path.module}/${var.superset_charts_custom_values_yaml}",
        {
           env                       = var.env
           superset_charts_namespace = var.superset_charts_namespace   
           superset_namespace        = var.superset_namespace
           superset_release_name     = var.superset_release_name
           superset_username         = var.superset_username
           superset_password         = var.superset_password
        }
      )
    ]
}