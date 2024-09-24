resource "helm_release" "docker_registry_secret" {
    name             = "redis-docker-secret"
    chart            = "${path.module}/docker-registry-secret-helm-chart"
    namespace        = var.redis_namespace
    create_namespace = true
    wait_for_jobs    = var.redis_wait_for_jobs
    timeout          = var.redis_install_timeout
    force_update     = true
    cleanup_on_fail  = true
    atomic           = true
    values = [
    templatefile("${path.module}/docker_registry_secrets.yaml.tfpl",
    {
        docker_registry_secret_dockerconfigjson     = var.docker_registry_secret_dockerconfigjson,
        docker_registry_secret_name                 = var.docker_registry_secret_name
    })
  ]
}

resource "helm_release" "redis" {
    name             = var.redis_release_name
    repository       = var.redis_chart_repository
    chart            = var.redis_chart_name
    version          = var.redis_chart_version
    namespace        = var.redis_namespace
    create_namespace = var.redis_create_namespace
    wait_for_jobs    = var.redis_wait_for_jobs
    timeout          = var.redis_install_timeout
    force_update     = true
    cleanup_on_fail  = true
    atomic           = true
    values = [
      templatefile("${path.module}/${var.redis_custom_values_yaml}",
        {
            redis_master_maxmemory            = var.redis_master_maxmemory            
            redis_replica_maxmemory           = var.redis_replica_maxmemory
            redis_maxmemory_eviction_policy   = var.redis_maxmemory_eviction_policy
            redis_persistence_path            = var.redis_persistence_path
            redis_master_persistence_size     = var.redis_master_persistence_size
            redis_replica_persistence_size    = var.redis_replica_persistence_size
            redis_backup_image_repository     = var.redis_backup_image_repository
            redis_backup_image_tag            = var.redis_backup_image_tag
            redis_backup_cron_schedule        = var.redis_backup_cron_schedule
            cloud_store_provider              = var.cloud_store_provider
            redis_backup_s3_bucket            = var.redis_backup_s3_bucket
            redis_backup_gcs_bucket           = var.redis_backup_gcs_bucket
            docker_registry_secret_name       = var.docker_registry_secret_name
            redis_backup_sa_annotations       = var.redis_backup_sa_annotations
            azure_storage_account_name        = var.azure_storage_account_name
            azure_storage_account_key         = var.azure_storage_account_key
            redis_backup_azure_bucket         = var.redis_backup_azure_bucket
            redis_backup_service_account_name = "${var.redis_namespace}-backup-sa"
        }
      )
    ]
}