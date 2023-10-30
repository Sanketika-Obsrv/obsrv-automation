resource "helm_release" "postgresql_exporter" {
    name             = var.postgresql_exporter_release_name
    chart            = "${path.module}/${var.postgresql_exporter_chart_path}"
    namespace        = var.postgresql_exporter_namespace
    create_namespace = var.postgresql_exporter_create_namespace
    wait_for_jobs    = var.postgresql_exporter_wait_for_jobs
    depends_on       = [var.postgresql_exporter_chart_depends_on]
    force_update      = true
    cleanup_on_fail   = true
    atomic            = true
    values = [
        templatefile("${path.module}/${var.postgresql_exporter_custom_values_yaml}",
        {
         postgresql_exporter_namespace = var.postgresql_exporter_namespace
        })
    ]
}