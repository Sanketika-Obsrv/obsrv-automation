resource "helm_release" "hms" {
  name             = var.hms_release_name
  chart            = "${path.module}/${var.hms_chart_path}"
  namespace        = var.hms_namespace
  create_namespace = var.hms_create_namespace
  depends_on       = [var.hms_chart_depends_on]
  force_update     = true
  cleanup_on_fail  = true
  atomic           = true
  values = [
    templatefile("${path.module}/${var.hms_custom_values_yaml}",
      {
        hms_image         = var.hms_image
        hms_replica_count = var.hms_replica_count
        hms_service       = var.hms_service
        hadoop_conf       = jsonencode(local.hadoop_configuration)
        hms_env_vars      = jsonencode(local.env_vars)
      }
    )
  ]
}
