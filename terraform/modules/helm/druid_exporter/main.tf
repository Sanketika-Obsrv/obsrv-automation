resource "helm_release" "druid_exporter" {
    name             = var.druid_exporter_release_name
    chart            = "${path.module}/${var.druid_exporter_chart_path}"
    namespace        = var.druid_exporter_namespace
    create_namespace = var.druid_exporter_create_namespace
    wait_for_jobs    = var.druid_exporter_wait_for_jobs
    timeout          = var.druid_exporter_install_timeout
    depends_on       = [var.druid_exporter_chart_depends_on]
    force_update     = true
    cleanup_on_fail  = true
    atomic           = true
    values = [
      templatefile("${path.module}/${var.druid_exporter_custom_values_yaml}",
        {
          druid_exporter_namespace  = var.druid_exporter_namespace
          env                       = var.env
        }
      )
    ]
}