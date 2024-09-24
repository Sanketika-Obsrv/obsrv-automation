resource "helm_release" "kafka_exporter" {
    name             = var.kafka_exporter_release_name
    chart            = "${path.module}/${var.kafka_exporter_chart_path}"
    namespace        = var.kafka_exporter_namespace
    create_namespace = var.kafka_exporter_create_namespace
    wait_for_jobs    = var.kafka_exporter_wait_for_jobs
    timeout          = var.kafka_exporter_install_timeout
    depends_on       = [var.kafka_exporter_chart_depends_on]
    force_update     = true
    cleanup_on_fail  = true
    atomic           = true
    values = [
      templatefile("${path.module}/${var.kafka_exporter_custom_values_yaml}",
      {
        kafka_exporter_namespace             = var.kafka_exporter_namespace
      }
      )
    ]
}