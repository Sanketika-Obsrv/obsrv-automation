resource "helm_release" "command-service" {
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
          docker_registry_secret_name                 = var.docker_registry_secret_name
      })
    ]
}