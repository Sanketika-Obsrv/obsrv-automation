variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}

variable "loki_release_name" {
  type        = string
  description = "Loki helm release name."
  default     = "loki"
}

variable "loki_namespace" {
  type        = string
  description = "Loki namespace."
  default     = "loki"
}

variable "loki_chart_install_timeout" {
  type        = number
  description = "Loki chart install timeout."
  default     = 3000
}

variable "loki_create_namespace" {
  type        = bool
  description = "Create loki namespace."
  default     = true
}

variable "loki_wait_for_jobs" {
  type        = bool
  description = "Loki wait for jobs paramater."
  default     = true
}

variable "loki_chart_repository" {
  type        = string
  description = "Loki chart repository url."
  default     = "https://grafana.github.io/helm-charts"
}

variable "loki_chart_name" {
  type        = string
  description = "Loki chart name."
  default     = "loki"
}

variable "loki_chart_version" {
  type        = string
  description = "Loki chart version."
  default     = "4.8.0"
}

variable "loki_install_timeout" {
  type        = number
  description = "Loki chart install timeout."
  default     = 1500
}

variable "loki_custom_values_yaml" {
  type        = string
  description = "Loki chart values.yaml path."
  default     = "loki.yaml.tfpl"
}

variable "minio_enabled" {
  type        = bool
  description = "Enable / disable minio so loki can store chunks and indexes."
  default     = true
}

variable "minio_service_monitor_enabled" {
  type        = bool
  description = "Enable / disable minio prometheus metrics."
  default     = true
}

variable "minio_include_node_metrics" {
  type        = bool
  description = "Enable / disable individual minio pod / node metrics."
  default     = true
}

variable "loki_auth_enabled" {
  type        = bool
  description = "Enable / disable multitenancy on loki."
  default     = false
}

variable "loki_dashboards_namespace" {
  type        = string
  description = "Namespace to create loki dashboards."
  default     = "monitoring"
}

variable "limits_config_enforce_metric_name" {
  type        = bool
  description = "Enforce every sample has a metric name."
  default     = false
}

variable "limits_config_reject_old_samples" {
  type        = bool
  description = "Whether or not old samples will be rejected."
  default     = true
}

variable "limits_config_reject_old_samples_max_age" {
  type        = string
  description = "Maximum accepted sample age before rejecting."
  default     = "168h"
}

variable "limits_config_max_cache_freshness_per_query" {
  type        = string
  description = "Most recent allowed cacheable result per-tenant, to prevent caching very recent results that might still be in flux."
  default     = "10m"
}

variable "limits_config_split_queries_by_interval" {
  type        = string
  description = "Split queries by a time interval and execute in parallel. The value 0 disables splitting by time. This also determines how cache keys are chosen when result caching is enabled"
  default     = "15m"
}

variable "limits_config_retention_period" {
  type        = string
  description = "Retention to apply for the store, if the retention is enable on the compactor side."
  default     = "48h"
}

variable "compactor_retention_enabled" {
  type        = bool
  description = "Activate retention using compactor."
  default     = true
}

variable "compactor_working_directory" {
  type        = string
  description = "Compactor working directory."
  default     = "/var/loki/compactor/retention"
}