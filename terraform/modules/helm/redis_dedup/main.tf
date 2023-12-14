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
            redis_master_maxmemory          = var.redis_master_maxmemory
            redis_replica_maxmemory         = var.redis_replica_maxmemory
            redis_maxmemory_eviction_policy = var.redis_maxmemory_eviction_policy
            redis_persistence_path          = var.redis_persistence_path
            redis_master_persistence_size   = var.redis_master_persistence_size
            redis_replica_persistence_size  = var.redis_replica_persistence_size
        }
      )
    ]
}