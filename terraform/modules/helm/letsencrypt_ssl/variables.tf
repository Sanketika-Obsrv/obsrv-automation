variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}

variable "letsencrypt_ssl_release_name" {
  type        = string
  description = "Letsencrypt ssl ingress helm release name."
  default     = "letsencrypt-ssl"
}

variable "letsencrypt_ssl_namespace" {
  type        = string
  description = "Letsencrypt ssl ingress namespace."
  default     = "cert-manager"
}

variable "letsencrypt_ssl_wait_for_jobs" {
  type        = bool
  description = "Letsencrypt ssl ingress wait for jobs paramater."
  default     = true
}

variable "letsencrypt_ssl_chart_path" {
  type        = string
  description = "Letsencrypt ssl helm chart path."
  default     = "letsencrypt-ssl-helm-chart"
}

variable "letsencrypt_ssl_install_timeout" {
  type        = number
  description = "Letsencrypt ssl ingress chart install timeout."
  default     = 600
}

variable "letsencrypt_ssl_custom_values_yaml" {
  type        = string
  description = "Letsencrypt ssl ingress chart values.yaml path."
  default     = "letsencrypt_ssl.yaml.tfpl"
}

variable "letsencrypt_ssl_issuer_name" {
  type        = string
  description = "Letsencrypt ssl issuer name."
  default     = "letsencrypt-prod"
}

variable "letsencrypt_ssl_admin_email" {
  type        = string
  description = "Letsencrypt ssl domain admin email."
}

variable "letsencrypt_server_url" {
  type        = string
  description = "Letsencrypt ssl server url."
  default     = "https://acme-v02.api.letsencrypt.org/directory"
}

variable "kong_ingress_domain" {
  type        = string
  description = "Kong ingress domain. Leave it empty if you dont have a domain name. If you have a domain, provide value such as obsrv.ai"
}
