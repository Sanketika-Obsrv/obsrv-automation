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
          postgresql_persistence_size          = var.postgresql_persistence_size
          postgresql_admin_username            = var.postgresql_admin_username
          postgresql_admin_password            = var.postgresql_admin_password
          postgresql_image_tag                 = var.postgresql_image_tag
      })
    ]
}
