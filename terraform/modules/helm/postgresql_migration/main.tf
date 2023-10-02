resource "helm_release" "postgresql_migration" {
    name             = var.postgresql_migration_release_name
    chart            = "${path.module}/${var.postgresql_migration_chart_path}"
    namespace        = var.postgresql_namespace
    wait_for_jobs    = var.postgresql_migration_wait_for_jobs
    timeout          = var.postgresql_migration_install_timeout
    depends_on       = [var.postgresql_migration_chart_depends_on]
    force_update     = true
    cleanup_on_fail  = true
    atomic           = true
    values = [
        templatefile("${path.module}/${var.postgresql_migration_custom_values_yaml}",
        {
          postgresql_namespace               = var.postgresql_namespace
          postgresql_url                     = var.postgresql_url
          postgresql_admin_username          = var.postgresql_admin_username
          postgresql_admin_password          = var.postgresql_admin_password
          postgresql_superset_user_password  = var.postgresql_superset_user_password
          postgresql_druid_raw_user_password = var.postgresql_druid_raw_user_password
          postgresql_obsrv_user_password     = var.postgresql_obsrv_user_password
        })
    ]
}