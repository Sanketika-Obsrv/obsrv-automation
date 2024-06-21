resource "helm_release" "lakehouse-connector" {
    name             = "lakehouse-connector"
    chart            = "${path.module}/${var.flink_chart_path}"
    namespace        = var.flink_namespace
    create_namespace = var.flink_create_namespace
    # depends_on       = [var.flink_chart_depends_on,helm_release.flink_sa]
    wait_for_jobs    = var.flink_wait_for_jobs
    timeout          = var.flink_chart_install_timeout
    force_update     = true
    cleanup_on_fail  = true
    atomic           = true
    values = [
      templatefile("${path.module}/${var.flink_custom_values_yaml}",
      {
          env                            = var.env
          flink_namespace                = var.flink_namespace
          flink_container_registry       = "${var.flink_container_registry}"
          flink_lakehouse_image_tag      = var.flink_lakehouse_image_tag
          flink_image_name               = var.flink_image_name
          checkpoint_store_type          = var.flink_checkpoint_store_type
          s3_access_key                  = var.s3_access_key
          s3_secret_key                  = var.s3_secret_key
          azure_account                  = var.azure_storage_account_name
          azure_secret                   = var.azure_storage_account_key
          postgresql_service_name        = var.postgresql_service_name
          postgresql_obsrv_username      = var.postgresql_obsrv_username
          postgresql_obsrv_user_password = var.postgresql_obsrv_user_password
          postgresql_obsrv_database      = var.postgresql_obsrv_database
          checkpoint_base_url            = var.checkpoint_base_url
          denorm_redis_namespace         = var.denorm_redis_namespace
          denorm_redis_release_name      = var.denorm_redis_release_name
          dedup_redis_namespace          = var.dedup_redis_namespace
          dedup_redis_release_name       = var.dedup_redis_release_name
          hadoop_configuration           = jsonencode(local.hadoop_configuration)
          enable_lakehouse                    = var.enable_lakehouse
          postgresql_hms_username        = var.postgresql_hms_username
          postgresql_hms_user_password   = var.postgresql_hms_user_password
          hudi_bucket                    = var.hudi_bucket
          hudi_prefix_path               = var.hudi_prefix_path
      })
    ]
}
