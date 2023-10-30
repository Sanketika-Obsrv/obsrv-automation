variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
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

variable "monitoring_chart_install_timeout" {
  type        = number
  description = "Monitoring chart install timeout."
  default     = 3000
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

variable "monitoring_chart_repository" {
  type        = string
  description = "Monitoring chart repository url."
  default     = "https://prometheus-community.github.io/helm-charts"
}

variable "monitoring_chart_name" {
  type        = string
  description = "Monitoring chart name."
  default     = "kube-prometheus-stack"
}

variable "monitoring_chart_version" {
  type        = string
  description = "Monitoring chart version."
  default     = "44.2.1"
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
variable "prometheus_metrics_retention" {
  type        = string
  description = "Prometheus metrics retention period."
  default     = "90d"
}