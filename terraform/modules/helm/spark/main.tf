resource "helm_release" "spark" {
    name              = var.spark_release_name
    chart             = "${path.module}/${var.spark_chart_path}"
    namespace         = var.spark_namespace
    create_namespace  = var.spark_create_namespace
    dependency_update = var.spark_chart_dependency_update
    wait_for_jobs     = var.spark_wait_for_jobs
    timeout           = var.spark_install_timeout
    force_update      = true
    cleanup_on_fail   = true
    atomic            = true
    values = [
      templatefile("${path.module}/${var.spark_chart_custom_values_yaml}",
        {
          env                               = var.env
          building_block                    = var.building_block
          spark_image_repository            = var.spark_image_repository
          spark_image_tag                   = var.spark_image_tag
          spark_metrics_topic               = var.spark_metrics_topic
          spark_metrics_version             = var.spark_metrics_version
          docker_registry_secret_name       = var.docker_registry_secret_name
          create_service_account            = var.create_service_account
          spark_namespace                   = var.spark_namespace
          spark_sa_annotations              = var.spark_sa_annotations
          kubernetes_storage_class          = var.kubernetes_storage_class
          postgresql_obsrv_username         = var.postgresql_obsrv_username
          postgresql_obsrv_password         = var.postgresql_obsrv_password
          postgresql_obsrv_database         = var.postgresql_obsrv_database
          s3_bucket                         = var.s3_bucket
          druid_cluster_release_name        = var.druid_cluster_release_name
          druid_cluster_namespace           = var.druid_cluster_namespace
          redis_release_name                = var.redis_release_name
          redis_namespace                   = var.redis_namespace
          cloud_provider                    = var.cloud_provider
          encryption_key                    = var.encryption_key
          s3_region                         = var.s3_region
          spark_sa_role                     = var.spark_sa_role
          cloud_storage_prefix              = var.cloud_storage_prefix
        }
      )
    ]
}
