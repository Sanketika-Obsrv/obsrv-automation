resource "helm_release" "dataset_api" {
    name             = var.dataset_api_release_name
    chart            = "${path.module}/${var.dataset_api_chart_path}"
    namespace        = var.dataset_api_namespace
    create_namespace = var.dataset_api_create_namespace
    wait_for_jobs    = var.dataset_api_wait_for_jobs
    timeout          = var.dataset_api_install_timeout
    depends_on       = [var.dataset_api_chart_depends_on]
    force_update     = true
    cleanup_on_fail  = true
    atomic           = true
    values = [
      templatefile("${path.module}/${var.dataset_api_custom_values_yaml}",
        {
          env                                = var.env
          dataset_api_namespace              = var.dataset_api_namespace
          postgresql_obsrv_username          = var.postgresql_obsrv_username
          postgresql_obsrv_user_password     = var.postgresql_obsrv_user_password
          postgresql_obsrv_database          = var.postgresql_obsrv_database
          dataset_api_container_registry     = var.dataset_api_container_registry
          dataset_api_image_name             = var.dataset_api_image_name
          dataset_api_image_tag              = var.dataset_api_image_tag
          dataset_api_sa_annotations         = var.dataset_api_sa_annotations
          redis_namespace                    = var.redis_namespace
          redis_release_name                 = var.redis_release_name
          s3_bucket                          = var.s3_bucket
        }
      )
    ]
}
