resource "helm_release" "letsencrypt_ssl" {
    name             = var.letsencrypt_ssl_release_name
    chart            = "${path.module}/${var.letsencrypt_ssl_chart_path}"
    namespace        = var.letsencrypt_ssl_namespace
    timeout          = var.letsencrypt_ssl_install_timeout
    cleanup_on_fail  = true
    atomic           = true
    values = [
      templatefile("${path.module}/${var.letsencrypt_ssl_custom_values_yaml}",
        {
          letsencrypt_ssl_issuer_name = var.letsencrypt_ssl_issuer_name
          letsencrypt_ssl_admin_email = var.letsencrypt_ssl_admin_email
          letsencrypt_server_url      = var.letsencrypt_server_url
          kong_ingress_domain         = var.kong_ingress_domain
        }
      )
    ]
}