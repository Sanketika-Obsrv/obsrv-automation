resource "helm_release" "submit_ingestion" {
    name             = var.submit_ingestion_release_name
    chart            = "${path.module}/${var.submit_ingestion_chart_path}"
    namespace        = var.submit_ingestion_namespace
    create_namespace = var.submit_ingestion_create_namespace
    depends_on       = [var.submit_ingestion_chart_depends_on]
    wait_for_jobs    = var.submit_ingestion_wait_for_jobs
    timeout          = var.submit_ingestion_chart_install_timeout
    force_update     = true
    cleanup_on_fail  = true
    atomic           = true
    values = [
      templatefile("${path.module}/${var.submit_ingestion_custom_values_yaml}",
        {
           env                        = var.env
           submit_ingestion_namespace = var.submit_ingestion_namespace
           druid_cluster_namespace    = var.druid_cluster_namespace
           druid_cluster_release_name = var.druid_cluster_release_name
        }
      )
    ]
}