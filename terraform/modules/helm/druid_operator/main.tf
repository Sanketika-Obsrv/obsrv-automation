resource "helm_release" "druid_operator" {
  name             = var.druid_operator_release_name
  chart            = "${path.module}/${var.druid_operator_chart_path}"
  timeout          = var.druid_operator_chart_install_timeout
  namespace        = var.druid_operator_namespace
  create_namespace = var.druid_operator_create_namespace
  wait_for_jobs    = var.druid_operator_wait_for_jobs
  force_update     = true
  cleanup_on_fail  = true
  atomic           = true
}