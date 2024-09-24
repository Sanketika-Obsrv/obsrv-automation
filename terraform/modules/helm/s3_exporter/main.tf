resource "helm_release" "s3_exporter" {
    name             = var.s3_exporter_release_name
    chart            = "${path.module}/${var.s3_exporter_chart_path}"
    namespace        = var.s3_exporter_namespace
    create_namespace = var.s3_exporter_create_namespace
    wait_for_jobs    = var.s3_exporter_wait_for_jobs
    timeout          = var.s3_exporter_install_timeout
    force_update     = true
    cleanup_on_fail  = true
    atomic           = true
    values = [
    templatefile("${path.module}/${var.s3_exporter_custom_values_yaml}",
      {
        s3_exporter_sa_annotations       = var.s3_exporter_sa_annotations
        s3_exporter_service_account_name = "${var.s3_exporter_namespace}-sa"
        s3_exporter_image_repository     = var.s3_exporter_image_repository
        s3_exporter_image_tag            = var.s3_exporter_image_tag
        s3_region                        = var.s3_region
      }
    )
  ]
}