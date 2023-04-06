variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
  default     = "dev"
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
  default     = "obsrv"
}

variable "postgresql_release_name" {
  type        = string
  description = "Postgresql helm release name."
  default     = "postgresql"
}

variable "postgresql_namespace" {
  type        = string
  description = "Postgresql namespace."
  default     = "postgresql"
}

variable "postgresql_install_timeout" {
  type        = number
  description = "Postgresql chart install timeout."
  default     = 900
}

variable "postgresql_create_namespace" {
  type        = bool
  description = "Create postgresql namespace."
  default     = true
}

variable "postgresql_custom_values_yaml" {
  type        = string
  description = "Postgresql chart custom values.yaml path."
  default     = "postgresql.yaml.tfpl"
}

variable "postgresql_dependecy_update" {
  type        = bool
  description = "Postgresql chart dependency update."
  default     = true
}

variable "postgresql_chart_path" {
  type        = string
  description = "Postgresql helm chart path."
  default     = "postgresql-helm-chart"
}

variable "postgresql_admin_username" {
  type        = string
  description = "Postgresql admin username."
  default     = "postgres"
}

variable "postgresql_admin_password" {
  type        = string
  description = "Postgresql admin password."
  default   = "postgres"
}

variable "postgresql_druid_database" {
  type        = string
  description = "Postgresql database name."
  default   = "druid_raw"
}

variable "postgresql_druid_user_name" {
  type        = string
  description = "Postgresql database name."
  default   = "druid_raw"
}

variable "postgresql_druid_user_password" {
  type        = string
  description = "Postgresql database name."
  default   = "druid_raw"
}

variable "postgresql_superset_user_password" {
  type        = string
  description = "Postgresql superset user password."
  default   = "superset123"
}

variable "postgresql_persistence_size" {
  type        = string
  description = "Postgresql persistent volume size."
  default   = "10Gi"
}

variable "postgresql_image_tag" {
  type = string
  description = "Postgresql image tag."
  default = "14.5.0-debian-11-r14"
}

variable "postgresql_flink_user_password" {
  type        = string
  description = "Postgresql flink user password."
  default   = "flink123"
}

variable "postgresql_druid_raw_user_password" {
  type        = string
  description = "Postgresql flink user password."
  default   = "druidraw123"
}

variable "postgresql_dataset_api_user_password" {
  type        = string
  description = "Postgresql flink user password."
  default   = "datasetapi123"
}