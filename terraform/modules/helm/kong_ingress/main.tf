resource "helm_release" "kong_ingress" {
    name             = var.kong_ingress_release_name
    repository       = var.kong_ingress_chart_repository
    chart            = var.kong_ingress_chart_name
    version          = var.kong_ingress_chart_version
    namespace        = var.kong_ingress_namespace
    create_namespace = var.kong_ingress_create_namespace
    wait_for_jobs    = var.kong_ingress_wait_for_jobs
    timeout          = var.kong_ingress_install_timeout
    force_update     = true
    cleanup_on_fail  = true
    atomic           = true
    disable_webhooks = true
    values = [
      templatefile("${path.module}/${var.kong_ingress_custom_values_yaml}",
        {
            kong_loadbalancer_annotations = var.kong_loadbalancer_annotations
            kong_ingress_aws_eip_ids       = var.kong_ingress_aws_eip_ids
            kong_ingress_aws_subnet_ids   = var.kong_ingress_aws_subnet_ids
        }
      )
    ]
}