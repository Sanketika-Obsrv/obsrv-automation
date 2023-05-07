resource "helm_release" "alertrules" {
    name             = var.alertrules_release_name
    chart            = "${path.module}/${var.alertrules_chart_path}"
    namespace        = var.alertrules_namespace
    create_namespace = var.alertrules_create_namespace
    depends_on       = [var.alertrules_chart_depends_on]
    force_update     = true
    cleanup_on_fail  = true
    atomic           = true
    values = [
      templatefile("${path.module}/${var.alertrules_custom_values_yaml}",
        {
          alertrules_namespace = var.alertrules_namespace
        }
      )
    ]
}