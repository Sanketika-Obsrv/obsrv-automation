variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}

variable "druid_exporter_release_name" {
  type        = string
  description = "Druid exporter helm release name."
  default     = "druid-exporter"
}

variable "druid_exporter_namespace" {
  type        = string
  description = "Druid exporter namespace."
  default     = "druid-raw"
}

variable "druid_exporter_chart_path" {
  type        = string
  description = "Druid exporter chart path."
  default     = "druid-exporter-helm-chart"
}

variable "druid_exporter_create_namespace" {
  type        = bool
  description = "Create druid exporter namespace."
  default     = true
}

variable "druid_exporter_wait_for_jobs" {
  type        = bool
  description = "Druid exporter wait for jobs paramater."
  default     = true
}

variable "druid_exporter_custom_values_yaml" {
  type = string
  default = "druid_exporter.yaml.tfpl"
}

variable "druid_exporter_install_timeout" {
  type        = number
  description = "Druid exporter chart install timeout."
  default     = 1200
}

variable "druid_exporter_chart_depends_on" {
  type        = any
  description = "List of helm release names that this chart depends on."
  default     = ""
}