resource "helm_release" "postgresql" {
    name              = var.postgresql_release_name
    chart             = "${path.module}/${var.postgresql_chart_path}"
    timeout           = var.postgresql_install_timeout
    namespace         = var.postgresql_namespace
    create_namespace  = var.postgresql_create_namespace
    dependency_update = var.postgresql_dependecy_update
    force_update      = true
    cleanup_on_fail   = true
    atomic            = true
    values = [
      templatefile("${path.module}/${var.postgresql_custom_values_yaml}",
       {
          postgresql_admin_password            = var.postgresql_admin_password
          postgresql_druid_database            = var.postgresql_druid_database
          postgresql_druid_user_name           = var.postgresql_druid_user_name
          postgresql_druid_user_password       = var.postgresql_druid_user_password
          postgresql_persistence_size          = var.postgresql_persistence_size
          postgresql_admin_username            = var.postgresql_admin_username
          postgresql_admin_password            = var.postgresql_admin_password
          postgresql_superset_user_password    = var.postgresql_superset_user_password
          postgresql_image_tag                 = var.postgresql_image_tag
          postgresql_flink_user_password       = var.postgresql_flink_user_password
          postgresql_druid_raw_user_password   = var.postgresql_druid_raw_user_password
          postgresql_dataset_api_user_password = var.postgresql_dataset_api_user_password
          postgresql_obsrv_username            = var.postgresql_obsrv_username
          postgresql_obsrv_user_password       = var.postgresql_obsrv_user_password
          postgresql_obsrv_database            = var.postgresql_obsrv_database
      })
    ]
}