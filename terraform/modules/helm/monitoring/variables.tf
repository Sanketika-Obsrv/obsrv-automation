variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}

variable "service_type" {
  type = string
  description = "Kubernetes service type either LoadBalancer or NodePort. It is LoadBalancer by default"  
}

variable "monitoring_release_name" {
  type        = string
  description = "Monitoring helm release name."
  default     = "monitoring"
}

variable "monitoring_namespace" {
  type        = string
  description = "Monitoring namespace."
  default     = "monitoring"
}

variable "monitoring_create_namespace" {
  type        = bool
  description = "Create monitoring namespace."
  default     = true
}

variable "monitoring_wait_for_jobs" {
  type        = bool
  description = "Monitoring wait for jobs paramater."
  default     = true
}

variable "monitoring_chart_path" {
  type        = string
  description = "Monitoring chart repository url."
  default     = "monitoring-helm-chart"
}

variable "monitoring_chart_name" {
  type        = string
  description = "Monitoring chart name."
  default     = "kube-prometheus-stack"
}

variable "monitoring_chart_version" {
  type        = string
  description = "Monitoring chart version."
  default     = "46.5.0"
}

variable "monitoring_install_timeout" {
  type        = number
  description = "Monitoring chart install timeout."
  default     = 1200
}

variable "prometheus_persistent_volume_size" {
  type        = string
  description = "Persistent volume size for prometheus metrics data."
  default     = "10Gi"
}

variable "monitoring_custom_values_yaml" {
  type        = string
  description = "Monitoring chart values.yaml path."
  default     = "monitoring.yaml.tfpl"
}

variable "monitoring_grafana_oauth_configs" {
  type        = map
  description = "Grafana oauth related variables. See below commented code for values that need to be passed"
  # default     = {
  #   "gf_auth_generic_oauth_enabled"          = false
  #   "gf_auth_generic_oauth_name"             = ""
  #   "gf_auth_generic_oauth_allow_sign_up"    = false
  #   "gf_auth_generic_oauth_client_id"        = ""
  #   "gf_auth_generic_oauth_client_secret"    = ""
  #   "gf_auth_generic_oauth_scopes"           = ""
  #   "gf_auth_generic_oauth_auth_url"         = ""
  #   "gf_auth_generic_oauth_token_url"        = ""
  #   "gf_auth_generic_oauth_api_url"          = ""
  #   "gf_auth_generic_oauth_auth_http_method" = ""
  #   "gf_auth_generic_oauth_username_field"   = ""
  #    "gf_security_allow_embedding"           = ""
  # }
}

variable "s3_backups_bucket" {
  type        = string
  description = "The s3 bucket name where the backups are stored."
}

variable "velero_storage_bucket" {
  type        = string
  description = "The s3 bucket name where the velerao backups are stored."
}

variable "s3_bucket" {
  type        = string
  description = "The s3 bucket name where druid and secor data are stored."
}

variable "checkpoint_storage_bucket" {
  type        = string
  description = "The s3 bucket name where flink checkpoints are stored."
}

variable "backup_folder_prefixes" {
  type        = list(string)
  description = "The list of individual folders that we want to monitor in the backup s3 backup bucket."
  default     = ["postgresql","dedup-redis","denorm-redis"]
}

variable "grafana_persistent_volume_size" {
  type        = string
  description = "Persistent volume size for grafana data."
  default     = "1Gi"
}

variable "prometheus_metrics_retention" {
  type        = string
  description = "Prometheus metrics retention period."
  default     = "90d"
}

variable "kong_ingress_domain" {
  type        = string
  description = "Kong ingress domain. Leave it empty if you dont have a domain name. If you have a domain, provide value such as obsrv.ai"
}

variable "grafana_ingress_path" {
  type        = string
  description = "Grafana sub path"
  default     = "/grafana"
}

variable "smtp_enabled" {
  type        = bool
  description = "enable the smtp server"
  default     = false
}

variable "smtp_config" {
  type                = map(string)
  description         = "smtp server configuration"
  default             = {
    host              = ""
    user              = ""
    password          = ""
    from_address      = ""
    cert_file         = ""
    key_file          = ""
    ehlo_identity     = ""
    startTLS_policy   = ""
    skip_verify       = "true"
    from_name         = "obsrv"
  }
}