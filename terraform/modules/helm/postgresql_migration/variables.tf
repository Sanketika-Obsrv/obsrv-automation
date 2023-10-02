variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}

variable "postgresql_migration_release_name" {
  type        = string
  description = "Postgres migration helm release name."
  default     = "postgresql-migration"
}

variable "postgresql_migration_chart_path" {
  type        = string
  description = "Postgresql migration chart path."
  default     = "postgresql-migration-helm-chart"
}

variable "postgresql_migration_wait_for_jobs" {
  type        = bool
  description = "Postgresql migration wait for jobs paramater."
  default     = true
}

variable "postgresql_migration_custom_values_yaml" {
  type = string
  default = "postgresql_migration.yaml.tfpl"
}

variable "postgresql_migration_chart_depends_on" {
  type        = any
  description = "List of helm release names that this chart depends on."
  default     = ""
}

variable "postgresql_migration_install_timeout" {
  type        = number
  description = "Web console chart install timeout."
  default     = 600
}

variable "postgresql_namespace" {
  type        = string
  description = "Postgresql namespace."
  default     = "postgresql"
}

variable "postgresql_url" {
  type        = string
  description = "Postgresql url."
}

variable "postgresql_admin_username" {
  type        = string
  description = "Postgresql admin username."
}

variable "postgresql_admin_password" {
  type        = string
  description = "Postgresql admin password."
}

variable "postgresql_superset_user_password" {
  type        = string
  description = "Postgresql superset user password."
}

variable "postgresql_druid_raw_user_password" {
  type        = string
  description = "Postgresql druid user password."
}

variable "postgresql_obsrv_user_password" {
  type        = string
  description = "Postgresql obsrv user password."
}