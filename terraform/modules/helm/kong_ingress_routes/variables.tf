variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}

variable "kong_ingress_routes_release_name" {
  type        = string
  description = "Kong ingress routes helm release name."
  default     = "kong-ingress-routes"
}

variable "kong_ingress_routes_namespace" {
  type        = string
  description = "Kong ingress routes namespace."
  default     = "kong-ingress-routes"
}

variable "kong_ingress_routes_create_namespace" {
  type        = bool
  description = "Create kong-ingress-routes namespace."
  default     = true
}

variable "kong_ingress_routes_install_timeout" {
  type        = number
  description = "Kong ingress routes chart install timeout."
  default     = 600
}

variable "kong_ingress_routes_custom_values_yaml" {
  type        = string
  description = "Kong ingress routes chart values.yaml path."
  default     = "kong_ingress_routes.yaml.tfpl"
}

variable "kong_ingress_routes_chart_path" {
  type        = string
  description = "Kong ingress routes helm chart path."
  default     = "kong-ingress-routes-helm-chart"
}

variable "kong_ingress_domain" {
  type        = string
  description = "Kong ingress domain. Leave it empty if you dont have a domain name. If you have a domain, provide value such as obsrv.ai"
}
