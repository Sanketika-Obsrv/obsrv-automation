variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}

variable "superset_charts_release_name" {
  type        = string
  description = "superset charts helm release name."
  default     = "superset-charts"
}

variable "superset_charts_namespace" {
  type        = string
  description = "superset charts namespace."
  default     = "superset-charts"
}

variable "superset_charts_chart_path" {
  type        = string
  description = "superset charts chart path."
  default     = "superset-charts-helm-chart"
}

variable "superset_charts_chart_install_timeout" {
  type        = number
  description = "superset charts chart install timeout."
  default     = 600
}

variable "superset_charts_create_namespace" {
  type        = bool
  description = "Create superset charts namespace."
  default     = true
}

variable "superset_charts_wait_for_jobs" {
  type        = bool
  description = "superset charts wait for jobs paramater."
  default     = true
}

variable "superset_charts_custom_values_yaml" {
  type        = string
  description = "Superset charts chart values.yaml path."
  default     = "superset-charts.yaml.tfpl"
}

variable "superset_charts_depends_on" {
  type        = any
  description = "List of helm release names that this chart depends on."
  default     = ""
}

variable "superset_release_name" {
  type        = any
  description = "superset release name"
  default     = "superset"
}

variable "superset_namespace" {
  type        = any
  description = "superset namespace"
  default     = "superset"
}

variable "superset_username" {
  type        = any
  description = "superset username"
  default     = "admin"
}

variable "superset_password" {
  type        = any
  description = "superset password"
  default     = "admin123"
}