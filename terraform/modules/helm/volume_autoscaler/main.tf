resource "helm_release" "volume_autoscaler" {
    name             = var.volume_autoscaler_release_name
    chart            = "${path.module}/${var.volume_autoscaler_chart_path}"
    namespace        = var.volume_autoscaler_namespace
    create_namespace = var.volume_autoscaler_create_namespace
    wait_for_jobs    = var.volume_autoscaler_wait_for_jobs
    timeout          = var.volume_autoscaler_install_timeout
    force_update     = true
    cleanup_on_fail  = true
    atomic           = true
    values = [
    templatefile("${path.module}/${var.volume_autoscaler_custom_values_yaml}",
      {
        prometheus_url     = var.prometheus_url
      }
    )
  ]
}