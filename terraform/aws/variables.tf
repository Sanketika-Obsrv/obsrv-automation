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

variable "region" {
  type        = string
  description = "AWS region to create the resources."
  default     = "us-east-2"
}

variable "flink_checkpoint_store_type" {
  type        = string
  description = "Flink checkpoint store type."
  default     = "s3"
}

variable "druid_deepstorage_type" {
  type        = string
  description = "Druid deep strorage type."
  default     = "s3"
}

variable "kubernetes_storage_class" {
  type        = string
  description = "Storage class name for the Kubernetes cluster"
  default     = "gp2"
}

variable "dataset_api_container_registry" {
  type        = string
  description = "Container registry. For example docker.io/obsrv"
  default     = "sanketikahub"
}

variable "dataset_api_image_tag" {
  type        = string
  description = "Dataset api image tag."
  default     = "1.0.4"
}

variable "flink_container_registry" {
  type        = string
  description = "Container registry. For example docker.io/obsrv"
  default     = "sanketikahub"
}

variable "flink_image_tag" {
   type        = string
   description = "Flink kubernetes service name."
   default     = "default"
}

variable "flink_image_map" {
  description = "Create release names"
  type        = map(string)
  default = {
    merged-pipeline = "merged-pipeline"
    unified-pipeline = "unified-pipeline"
    extractor       = "extractor"
    preprocessor    = "preprocessor"
    denormalizer    = "denormalizer"
    transformer     = "transformer"
    druid-router    = "druid-router"
  }
}
variable "monitoring_grafana_oauth_configs" {
  type        = map
  description = "Grafana oauth related variables. See below commented code for values that need to be passed"
  # default     = {
  #   gf_auth_generic_oauth_enabled          = false
  #   gf_auth_generic_oauth_name             = ""
  #   gf_auth_generic_oauth_allow_sign_up    = false
  #   gf_auth_generic_oauth_client_id        = ""
  #   gf_auth_generic_oauth_client_secret    = ""
  #   gf_auth_generic_oauth_scopes           = ""
  #   gf_auth_generic_oauth_auth_url         = ""
  #   gf_auth_generic_oauth_token_url        = ""
  #   gf_auth_generic_oauth_api_url          = ""
  #   gf_auth_generic_oauth_auth_http_method = ""
  #   gf_auth_generic_oauth_username_field   = ""
  # }
}

# web console variables start
variable "web_console_configs" {
  type = map
  description = "Web console config variables. See below commented code for values that need to be passed"
  # default = {
  #   port                               =
  #   app_name                           =
  #   prometheus_url                     =
  #   config_api_url                     =
  #   obs_api_url                        =
  #   system_api_url                     =
  #   alert_manager_url                  =
  #   grafana_url                        =
  #   superset_url                       =
  #   react_app_grafana_url              =
  #   react_app_superset_url             =
  #   session_secret                     =
  #   postgres_connection_string         =
  #   oauth_web_console_url              =
  #   auth_keycloak_realm                =
  #   auth_keycloak_public_client        =
  #   auth_keycloak_ssl_required         =
  #   auth_keycloak_client_id            =
  #   auth_keycloak_client_secret        =
  #   auth_keycloak_server_url           =
  #   auth_google_client_id              =
  #   auth_google_client_secret          =
  #   https                              =
  #   react_app_version                  =
  #   generate_sourcemap                 =
  # }
}

variable "web_console_image_repository" {
  type        = string
  description = "Container registry. For example docker.io/obsrv"
  default     = "sanketikahub/obsrv-web-console"
}

variable "web_console_image_tag" {
  type        = string
  description = "web console image tag."
  default = "1.0.1"
}
# web console variables end.

variable "docker_registry_secret_dockerconfigjson" {
  type        = string
  description = "The dockerconfigjson encoded in base64 format."
}

variable "command_service_image_tag" {
  type        = string
  description = "CommandService image tag."
  default     = "1.0.2"
}

variable "web_console_base_url" {
  type        = string
  description = "Web console base url."
  default = "http://webconsole.obsrv.ai"
}

variable "superset_base_url" {
  type        = string
  description = "Superset base url."
  default = "http://superset.obsrv.ai"
}

variable "oauth_configs" {
  type = map
  description = "Superset config variables. See the below commented code to know values to be passed "
  # default = {
  #   superset_oauth_clientid           =
  #   superset_oauth_client_secret      =
  #   superset_oauth_token              =
  # }
}

variable "kafka_topic" {
  type        = string
  description = "Kafka topic name from which the messages will be read."
  default     = "dev.stats"
}
