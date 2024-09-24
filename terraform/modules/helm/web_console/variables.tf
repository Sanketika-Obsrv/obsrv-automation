variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}
variable "service_type" {
  type = string
  description = "Kubernetes service type either NodePort or LoadBalancer. It is NodePort by default"
}

variable "web_console_release_name" {
  type        = string
  description = "Dataset service helm release name."
  default     = "web-console"
}

variable "web_console_namespace" {
  type        = string
  description = "Dataset service namespace."
  default     = "web-console"
}

variable "web_console_chart_path" {
  type        = string
  description = "Dataset service chart path."
  default     = "web-console-helm-chart"
}

variable "web_console_create_namespace" {
  type        = bool
  description = "Create Dataset service namespace."
  default     = true
}

variable "web_console_custom_values_yaml" {
  type = string
  default = "web_console.yaml.tfpl"
}

variable "web_console_chart_depends_on" {
  type        = any
  description = "List of helm release names that this chart depends on."
  default     = ""
}

variable "web_console_image_repository" {
  type        = string
  description = "Container registry. For example docker.io/obsrv"
  default     = "sanketikahub/obsrv-web-console"
}

variable "web_console_image_tag" {
  type        = string
  description = "web console image tag."
}

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
  #   auth_ad_url                        =
  #   auth_ad_user_name                  =
  #   auth_ad_base_dn                    =
  #   auth_ad_password                   =
  #   react_app_authentication_allowed_types =
  #   auth_oidc_issuer                   =
  #   auth_oidc_authrization_url         =
  #   auth_oidc_token_url                =
  #   auth_oidc_user_info_url            =
  #   auth_oidc_client_id                =
  #   auth_oidc_client_secret            =
  #   gf_bearer_token                    =
  # }
}

variable "docker_registry_secret_dockerconfigjson" {
  type        = string
  description = "The dockerconfigjson encoded in base64 format."
  sensitive   = true
}

variable "docker_registry_secret_name" {
  type        = string
  description = "Kubernetes secret name to pull images from private docker registry."
}
variable "grafana_service_account_name" {
  type = string
  description = "Service account in for grafana for auth token generation"
  default = "webconsole-sa"
}

variable "web_console_install_timeout" {
  type        = number
  description = "Web console chart install timeout."
  default     = 1200
}
variable "grafana_secret_name" {
  type        = string
  description = "The name of the secret. This will be sent back as an output which can be used in other modules"
  default     = "grafana-secret"
}

variable "kong_ingress_domain" {
  type        = string
  description = "Kong ingress domain. Leave it empty if you dont have a domain name. If you have a domain, provide value such as obsrv.ai"
}
variable "grafana_secret_allowed_namespaces" {
  type = string
  description = "namespace of dataset-api"
  default     = "web-console,dataset-api"
}
