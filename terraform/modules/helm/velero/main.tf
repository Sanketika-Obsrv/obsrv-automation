resource "helm_release" "velero" {
    name             = var.velero_release_name
    repository       = var.velero_chart_repository
    chart            = var.velero_chart_name
    version          = var.velero_chart_version
    namespace        = var.velero_namespace
    create_namespace = var.velero_create_namespace
    wait_for_jobs    = var.velero_wait_for_jobs
    timeout          = var.velero_install_timeout
    force_update     = true
    cleanup_on_fail  = true
    atomic           = true
    values = [
        var.cloud_provider == "aws" ? templatefile("${path.module}/${var.aws_velero_custom_values_yaml}",
        {
            cloud_provider               = var.cloud_provider
            velero_backup_bucket         = var.velero_backup_bucket
            velero_backup_bucket_region  = var.velero_backup_bucket_region
            velero_aws_access_key_id     = var.velero_aws_access_key_id
            velero_aws_secret_access_key = var.velero_aws_secret_access_key
        }) : var.cloud_provider == "gcp" ? templatefile("${path.module}/${var.gcp_velero_custom_values_yaml}",
        {
            cloud_provider               = var.cloud_provider
            velero_backup_bucket         = var.velero_backup_bucket
            velero_backup_bucket_region  = var.velero_backup_bucket_region
            velero_sa_iam_role_name      = "${var.building_block}-${var.velero_sa_iam_role_name}"
            sa_name                      = var.velero_sa_name
            project_id                   = var.gcp_project_id
            velero_sa_annotations        = var.velero_sa_annotations
        }) : var.cloud_provider == "azure" ? true : false
    ]
}