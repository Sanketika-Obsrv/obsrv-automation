variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}

variable "volume_autoscaler_release_name" {
  type        = string
  description = "Volume autoscaler helm release name."
  default     = "volume-autoscaler"
}

variable "volume_autoscaler_namespace" {
  type        = string
  description = "Volume autoscaler namespace."
  default     = "volume-autoscaler"
}

variable "volume_autoscaler_create_namespace" {
  type        = bool
  description = "Create volume autoscaler namespace."
  default     = true
}

variable "volume_autoscaler_wait_for_jobs" {
  type        = bool
  description = "Volume autoscaler wait for jobs parameter."
  default     = true
}

variable "volume_autoscaler_install_timeout" {
  type        = number
  description = "Volume autoscaler chart install timeout."
  default     = 600
}

variable "volume_autoscaler_chart_path" {
  type        = string
  description = "Volume autoscaler helm chart path."
  default     = "volume-autoscaler-helm-chart"
}

variable "volume_autoscaler_custom_values_yaml" {
  type        = string
  description = "Superset helm chart values.yaml path."
  default     = "volume_autoscaler.yaml.tfpl"
}

variable "prometheus_url" {
  type        = string
  description = "Prometheus endpoint."
  default     = "http://monitoring-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090"
}