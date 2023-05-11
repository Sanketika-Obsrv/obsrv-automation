resource "helm_release" "superset" {
    name             = var.superset_release_name
    chart            = "${path.module}/${var.superset_chart_path}"
    namespace        = var.superset_namespace
    create_namespace = var.superset_create_namespace
    wait_for_jobs    = var.superset_wait_for_jobs
    timeout          = var.superset_install_timeout
    depends_on       = [var.superset_chart_depends_on]
    force_update     = true
    cleanup_on_fail  = true
    atomic           = true
    values           = [
      templatefile("${path.module}/${var.superset_custom_values_yaml}",
      {
        pg_admin_username         = var.postgresql_admin_username
        pg_admin_password         = var.postgresql_admin_password
        pg_superset_user_password = var.postgresql_superset_user_password
        superset_image_tag        = var.superset_image_tag
        redis_namespace           = var.redis_namespace
        redis_release_name        = var.redis_release_name
      }
      )
    ]
}