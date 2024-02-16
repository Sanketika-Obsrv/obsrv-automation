resource "helm_release" "obsrv" {
    name             = var.obsrv_release_name
    chart            = "${path.module}/${var.obsrv_chart_path}"
    namespace        = var.obsrv_namespace
    create_namespace = var.obsrv_create_namespace
    wait_for_jobs    = var.obsrv_wait_for_jobs
    timeout          = var.obsrv_install_timeout
    depends_on       = [var.obsrv_chart_depends_on]
    force_update     = true
    cleanup_on_fail  = true
    atomic           = true
    
    values           = [  
      templatefile("${path.module}/${var.obsrv_custom_values_yaml}",{})
    ]
    set {
      name = "global.azure_storage_account_name"
      value = var.azure_storage_account_name
    }
    set {
      name = "global.azure_storage_account_key"
      value = var.azure_storage_account_key
    }
    set {
      name = "global.azure_storage_container"
      value = var.azure_storage_container
    }
}