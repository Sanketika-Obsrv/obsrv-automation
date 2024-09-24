resource "helm_release" "docker_registry_secret" {
    name             = "command-service-docker-secret"
    chart            = "${path.module}/docker-registry-secret-helm-chart"
    namespace        = var.command_service_namespace
    create_namespace = var.command_service_create_namespace
    depends_on       = [var.command_service_chart_depends_on]
    wait_for_jobs    = var.command_service_wait_for_jobs
    timeout          = var.command_service_chart_install_timeout
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

resource "helm_release" "command_service" {
    name             = var.command_service_release_name
    chart            = "${path.module}/${var.command_service_chart_path}"
    namespace        = var.command_service_namespace
    create_namespace = var.command_service_create_namespace
    depends_on       = [var.command_service_chart_depends_on]
    wait_for_jobs    = var.command_service_wait_for_jobs
    timeout          = var.command_service_chart_install_timeout
    force_update     = true
    cleanup_on_fail  = true
    atomic           = true
    values = [
      templatefile("${path.module}/${var.command_service_custom_values_yaml}",
            {
          env                                         = var.env
          command_service_image_repository            = var.command_service_image_repository
          command_service_image_tag                   = var.command_service_image_tag
          postgresql_obsrv_username                   = var.postgresql_obsrv_username
          postgresql_obsrv_user_password              = var.postgresql_obsrv_user_password
          postgresql_obsrv_database                   = var.postgresql_obsrv_database
          flink_namespace                             = var.flink_namespace
          druid_cluster_release_name                  = var.druid_cluster_release_name
          druid_cluster_namespace                     = var.druid_cluster_namespace
          docker_registry_secret_name                 = var.docker_registry_secret_name
          datasetFailedBatchEventsConfig              = var.datasetFailedBatchEventsConfig
          datasetDuplicateBatchEventsConfig           = var.datasetDuplicateBatchEventsConfig
          datasetDuplicateEventsConfig                = var.datasetDuplicateEventsConfig
          datasetValidationFailedEventsConfig         = var.datasetValidationFailedEventsConfig
          kafka_release_name                          = var.kafka_release_name
          kafka_namespace                             = var.kafka_namespace
          enable_lakehouse                            = var.enable_lakehouse

      })
    ]
}