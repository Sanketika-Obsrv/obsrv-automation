resource "helm_release" "flink" {
    name             = var.flink_release_name
    chart            = "${path.module}/${var.flink_chart_path}"
    namespace        = var.flink_namespace
    create_namespace = var.flink_create_namespace
    depends_on       = [var.flink_chart_depends_on]
    wait_for_jobs    = var.flink_wait_for_jobs
    timeout          = var.flink_chart_install_timeout
    force_update     = true
    cleanup_on_fail  = true
    atomic           = true
    values = [
      templatefile("${path.module}/${var.flink_custom_values_yaml}",
      {
          flink_container_registry       = "${var.flink_container_registry}/${var.flink_image_name}"
          flink_image_tag                = var.flink_image_tag
          checkpoint_store_type          = var.flink_checkpoint_store_type
          s3_access_key                  = var.s3_access_key
          s3_secret_key                  = var.s3_secret_key
          azure_account                  = var.azure_storage_account_name
          azure_secret                   = var.azure_storage_account_key
          postgresql_flink_user_password = var.postgresql_flink_user_password
          postgresql_admin_password      = var.postgresql_admin_password
          google_service_account_key_path= var.google_service_account_key_path
          checkpoint_base_url            = var.checkpoint_base_url
      })
    ]
}