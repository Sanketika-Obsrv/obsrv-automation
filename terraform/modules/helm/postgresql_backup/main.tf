resource "helm_release" "docker_registry_secret" {
    name             = "postgresql-docker-secret"
    chart            = "${path.module}/docker-registry-secret-helm-chart"
    namespace        = var.postgresql_backup_namespace
    create_namespace = true
    wait_for_jobs    = var.postgresql_backup_wait_for_jobs
    timeout          = var.postgresql_backup_install_timeout
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

resource "helm_release" "postgresql_backup" {
    name             = var.postgresql_backup_release_name
    chart            = "${path.module}/${var.postgresql_backup_chart_path}"
    namespace        = var.postgresql_backup_namespace
    create_namespace = var.postgresql_backup_create_namespace
    wait_for_jobs    = var.postgresql_backup_wait_for_jobs
    timeout          = var.postgresql_backup_install_timeout
    force_update     = true
    cleanup_on_fail  = true
    atomic           = true
    values = [
    templatefile("${path.module}/${var.postgresql_backup_custom_values_yaml}",
      {
        postgresql_backup_sa_annotations       = var.postgresql_backup_sa_annotations
        postgresql_backup_service_account_name = "${var.postgresql_backup_namespace}-backup-sa"
        postgresql_backup_image_repository     = var.postgresql_backup_image_repository
        postgresql_backup_image_tag            = var.postgresql_backup_image_tag
        postgresql_backup_cron_schedule        = var.postgresql_backup_cron_schedule
        postgresql_backup_postgres_user        = var.postgresql_backup_postgres_user
        postgresql_backup_postgres_host        = var.postgresql_backup_postgres_host
        postgresql_backup_postgres_password    = var.postgresql_backup_postgres_password
        postgresql_backup_cloud_service        = var.cloud_store_provider
        postgresql_backup_s3_bucket            = var.postgresql_backup_s3_bucket
        postgresql_backup_gcs_bucket           = var.postgresql_backup_gcs_bucket
        docker_registry_secret_name            = var.docker_registry_secret_name
      }
    )
  ]
}