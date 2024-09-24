variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}

variable "keycloak_release_name" {
  type        = string
  description = "Keycloak helm release name."
  default     = "keycloak"
}

variable "keycloak_namespace" {
  type        = string
  description = "Keycloak namespace."
  default     = "keycloak"
}

variable "keycloak_chart_path" {
  type        = string
  description = "Keycloak chart path."
  default     = "keycloak-helm-chart"
}

variable "keycloak_create_namespace" {
  type        = bool
  description = "Create keycloak namespace."
  default     = true
}

variable "keycloak_custom_values_yaml" {
  type = string
  default = "keycloak.yaml.tfpl"
}

variable "keycloak_install_timeout" {
  type        = number
  description = "Keycloak chart install timeout."
  default     = 1000
}

variable "keycloak_chart_depends_on" {
  type        = any
  description = "List of helm release names that this chart depends on."
  default     = ""
}
variable "service_type" {
  type = string
  description = "Kubernetes service type"
}

variable "kong_ingress_domain" {
  type        = string
  description = "Kong ingress domain. Leave it empty if you dont have a domain name. If you have a domain, provide value such as obsrv.ai"
}

variable "postgresql_service_name" {
  type        = string
  description = "Postgresql service name."
}