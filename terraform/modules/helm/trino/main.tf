resource "helm_release" "trino" {
  name             = var.trino_release_name
  chart            = "${path.module}/${var.trino_chart_path}"
  namespace        = var.trino_namespace
  create_namespace = var.trino_create_namespace
  depends_on       = [var.trino_chart_depends_on]
  force_update     = true
  cleanup_on_fail  = true
  atomic           = true
  values = [
    templatefile("${path.module}/${var.trino_custom_values_yaml}",
      {
        trino_namespace     = var.trino_namespace
        trino_image         = var.trino_image
        trino_workers_count = var.trino_workers_count
        trino_service       = var.trino_service
        trino_catalogs      = jsonencode({ for key, value in local.catalogs : key => join("\n", [for k, v in value : "${k}=${v}"]) })
      }
    )
  ]
}
