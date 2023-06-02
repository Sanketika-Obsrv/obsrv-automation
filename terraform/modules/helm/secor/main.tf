resource "helm_release" "secor_sa" {
  name             = "${var.secor_release_name}-sa"
  chart            = "${path.module}/${var.secor_chart_path}-sa"
  namespace        = var.secor_namespace
  create_namespace = var.secor_create_namespace
  wait_for_jobs    = var.secor_wait_for_jobs
  timeout          = var.secor_chart_install_timeout
  force_update     = true
  cleanup_on_fail  = true
  atomic           = true
  values = [
    templatefile("${path.module}/${var.secor_custom_values_yaml}-sa",
      {
        secor_namespace            = var.secor_namespace
        secor_sa_annotations       = var.secor_sa_annotations
        secor_service_account_name = "${var.secor_namespace}-sa"
      }
    )
  ]
}

resource "helm_release" "secor" {
  count            = length(var.jobs)
  name             = var.jobs[count.index]
  chart            = "${path.module}/${var.secor_chart_path}"
  namespace        = var.secor_namespace
  create_namespace = var.secor_create_namespace
  depends_on       = [var.secor_chart_depends_on, helm_release.secor_sa]
  wait_for_jobs    = var.secor_wait_for_jobs
  timeout          = var.secor_chart_install_timeout
  force_update     = true
  cleanup_on_fail  = true
  atomic           = true
  values = [
    templatefile("${path.module}/${var.secor_custom_values_yaml}",
      {
        cloud_store_provider       = var.cloud_store_provider
        upload_manager             = var.upload_manager
        deployment_stage           = var.env
        secor_namespace            = var.secor_namespace
        base_path                  = var.secor_backup_basepath
        default_timestamp_key      = var.secor_default_timestamp_key
        extractor_timestamp_key    = var.secor_extractor_timestamp_key
        fallback_timestamp_key     = var.fallback_timestamp_key
        message_timezone           = var.message_timezone
        parser_timezone            = var.parser_timezone
        image_pull_policy          = var.image_pull_policy
        storage_class              = var.storage_class
        env                        = var.env
        kafka_broker_host          = var.kafka_broker_ip
        zookeeper_quorum           = var.kafka_zookeeper_ip
        backup_pv_size             = var.secor_backup_pv_size
        request_cpu                = var.secor_cpu_request
        request_memory             = var.secor_memory_request
        secor_cpu_limit            = var.secor_cpu_limit
        secor_memory_limit         = var.secor_memory_limit
        secor_image_tag            = var.secor_image_tag
        jvm_memory                 = var.jvm_memory
        image_repository           = var.secor_image_repository
        cloud_storage_bucket       = var.cloud_storage_bucket
        region                     = var.region
        file_size                  = var.secor_backup_max_file_size
        file_age                   = var.secor_backup_interval
        threads                    = var.secor_threads_count
        parser_timezone            = var.parser_timezone
      }
    )
  ]
}