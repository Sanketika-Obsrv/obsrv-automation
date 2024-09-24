variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}

variable "grafana_configs_release_name" {
  type        = string
  description = "Grafana configs helm release name."
  default     = "grafana-configs"
}

variable "grafana_configs_namespace" {
  type        = string
  description = "Grafana configs namespace."
  default     = "monitoring"
}

variable "grafana_configs_chart_path" {
  type        = string
  description = "Grafana configs helm chart path."
  default     = "grafana-configs-helm-chart"
}

variable "grafana_configs_chart_install_timeout" {
  type        = number
  description = "Grafana configs helm chart install timeout."
  default     = 900
}

variable "grafana_configs_wait_for_jobs" {
  type        = bool
  description = "Grafana configs wait for jobs paramater."
  default     = true
}

variable "grafana_configs_create_namespace" {
  type        = bool
  description = "Create monitoring namespace."
  default     = true
}

variable "grafana_configs_chart_depends_on" {
  type        = any
  description = "List of helm release names that this chart depends on."
  default     = ""
}