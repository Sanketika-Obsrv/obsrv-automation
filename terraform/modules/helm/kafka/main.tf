resource "helm_release" "kafka" {
    name              = var.kafka_release_name
    chart             = "${path.module}/${var.kafka_chart_path}"
    namespace         = var.kafka_namespace
    create_namespace  = var.kafka_create_namespace
    dependency_update = var.kafka_chart_dependency_update
    wait_for_jobs     = var.kafka_wait_for_jobs
    timeout           = var.kafka_install_timeout
    force_update      = true
    cleanup_on_fail   = true
    atomic            = true
    values = [
      templatefile("${path.module}/${var.kafka_chart_custom_values_yaml}",
        {
          input_topic                  = "${var.env}.${var.kafka_input_topic}"
          input_masterdata_topic       = "${var.env}.${var.kafka_input_masterdata_topic}"
        }
      )
    ]
}