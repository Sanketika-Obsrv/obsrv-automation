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
variable "postgresql_keycloak_user_password" {
  type          = string
  description   = "Postgresql keycloak user password"
}

variable "web_console_credentials" {
  type = map
  description = "web console credentials"
  # default = {
  #   web_console_password   =
  #   web_console_login      =
  # }

}

# variable "superset_redirect_uri" {
#   type = string
#   description = "superset redirect url for webconsole"

# }

# variable "grafana_redirect_uri" {
#   type = string
#   description = "grafana redirect url for webconsole"

# }

variable "oauth_configs" {
  type = map
  description = "Superset config variables. See the below commented code to know values to be passed in postgres "
  # default = {
  #   superset_oauth_clientid           =
  #   superset_oauth_client_secret      =
  # }
}

variable "monitoring_grafana_oauth_configs" {
  type        = map
  description = "Grafana oauth related variables. See below commented code for values that need to be passed in postgres"
  # default     = {
  #   "gf_auth_generic_oauth_client_id"        = ""
  #   "gf_auth_generic_oauth_client_secret"    = ""
  # }
}

variable "kong_ingress_domain" {
  type        = string
  description = "Kong ingress domain. Leave it empty if you dont have a domain name. If you have a domain, provide value such as obsrv.ai"
}

variable "data_encryption_key" {
  type        = string
  description = "Data encryption key. This is used to encrypt data in pipeline. This is a 32 character string."
}


variable "postgresql_hms_user_password" {
  type        = string
  description = "Postgresql hms user password."
}
variable "enable_lakehouse" {
  type        = bool
  description = "Toggle to install hudi components (hms, trino and flink job)"
}