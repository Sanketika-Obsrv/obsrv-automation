variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}

variable "promtail_release_name" {
  type        = string
  description = "Promtail helm release name."
  default     = "promtail"
}

variable "promtail_namespace" {
  type        = string
  description = "Promtail namespace."
  default     = "loki"
}

variable "promtail_chart_install_timeout" {
  type        = number
  description = "Promtail chart install timeout."
  default     = 3000
}

variable "promtail_create_namespace" {
  type        = bool
  description = "Create promtail namespace."
  default     = true
}

variable "promtail_wait_for_jobs" {
  type        = bool
  description = "Promtail wait for jobs paramater."
  default     = true
}

variable "promtail_chart_repository" {
  type        = string
  description = "Promtail chart repository url."
  default     = "https://grafana.github.io/helm-charts"
}

variable "promtail_chart_name" {
  type        = string
  description = "Promtail chart name."
  default     = "promtail"
}

variable "promtail_chart_version" {
  type        = string
  description = "Promtail chart version."
  default     = "6.9.3"
}

variable "promtail_install_timeout" {
  type        = number
  description = "Promtail chart install timeout."
  default     = 1200
}

variable "promtail_custom_values_yaml" {
  type        = string
  description = "Promtail chart values.yaml path."
  default     = "promtail.yaml.tfpl"
}

variable "promtail_service_monitor_status" {
  type        = bool
  description = "Enable / Disable service monitor for promtail."
  default     = true
}

variable "promtail_chart_depends_on" {
  type        = any
  description = "List of helm release names that this chart depends on."
  default     = ""
}