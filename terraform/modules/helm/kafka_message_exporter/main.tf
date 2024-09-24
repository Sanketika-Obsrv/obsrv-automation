resource "helm_release" "docker_registry_secret" {
    name             = "kafka-docker-secret"
    chart            = "${path.module}/docker-registry-secret-helm-chart"
    namespace        = var.kafka_message_exporter_namespace
    create_namespace = true
    wait_for_jobs    = var.kafka_message_exporter_wait_for_jobs
    timeout          = var.kafka_message_exporter_install_timeout
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

resource "helm_release" "kafka_message_exporter" {
    name             = var.kafka_message_exporter_release_name
    chart            = "${path.module}/${var.kafka_message_exporter_chart_path}"
    namespace        = var.kafka_message_exporter_namespace
    wait_for_jobs    = var.kafka_message_exporter_wait_for_jobs
    timeout          = var.kafka_message_exporter_install_timeout
    force_update     = true
    cleanup_on_fail  = true
    atomic           = true
    values = [
    templatefile("${path.module}/${var.kafka_message_exporter_custom_values_yaml}",
      {
        kafka_message_exporter_image_repository = var.kafka_message_exporter_image_repository
        kafka_message_exporter_image_tag        = var.kafka_message_exporter_image_tag
        kafka_host                              = var.kafka_host
        docker_registry_secret_name             = var.docker_registry_secret_name
        spark_metrics_topic                     = var.spark_metrics_topic
        env                                     = var.env
      }
    )
  ]
}
