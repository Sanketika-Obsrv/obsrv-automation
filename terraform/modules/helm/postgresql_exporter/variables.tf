variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}

variable "postgresql_exporter_release_name" {
  type        = string
  description = "Postgres exporter helm release name."
  default     = "postgresql-exporter"
}

variable "postgresql_exporter_namespace" {
  type        = string
  description = "Postgres exporter namespace."
  default     = "postgresql"
}

variable "postgresql_exporter_chart_path" {
  type        = string
  description = "Postgresql exporter chart path."
  default     = "postgresql-exporter-helm-chart"
}

variable "postgresql_exporter_create_namespace" {
  type        = bool
  description = "Create postgresql exporter namespace."
  default     = true
}

variable "postgresql_exporter_wait_for_jobs" {
  type        = bool
  description = "Postgresql exporter wait for jobs paramater."
  default     = true
}

variable "postgresql_exporter_custom_values_yaml" {
  type = string
  default = "postgresql_exporter.yaml.tfpl"
}

variable "postgresql_exporter_chart_depends_on" {
  type        = any
  description = "List of helm release names that this chart depends on."
  default     = ""
}