resource "helm_release" "druid_cluster" {
  name             = var.druid_cluster_release_name
  chart            = "${path.module}/${var.druid_cluster_chart_path}"
  timeout          = var.druid_cluster_chart_install_timeout
  namespace        = var.druid_cluster_namespace
  create_namespace = var.druid_cluster_create_namespace
  depends_on       = [var.druid_raw_cluster_chart_depends_on]
  wait_for_jobs    = var.druid_cluster_wait_for_jobs
  force_update     = true
  cleanup_on_fail  = true
  atomic           = true
  values = [
    templatefile("${path.module}/${var.druid_cluster_custom_values_yaml}",
      {
        druid_namespace             = var.druid_cluster_namespace
        druid_raw_user              = var.druid_raw_user
        druid_raw_database          = var.druid_raw_database
        druid_raw_user_password     = var.druid_raw_user_password
        druid_worker_capacity       = var.druid_worker_capacity
        env                         = var.env
        kubernetes_storage_class    = var.kubernetes_storage_class
        druid_deepstorage_type      = var.druid_deepstorage_type
        s3_bucket                   = var.s3_bucket
        s3_access_key               = var.s3_access_key
        s3_secret_key               = var.s3_secret_key
        azure_storage_account_name  = var.azure_storage_account_name
        azure_storage_account_key   = var.azure_storage_account_key
        azure_storage_container     = var.azure_storage_container
      }
    )
  ]
}