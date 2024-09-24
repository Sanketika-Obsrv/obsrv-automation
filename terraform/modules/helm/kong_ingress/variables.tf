variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}

variable "kong_ingress_release_name" {
  type        = string
  description = "Kong ingress helm release name."
  default     = "kong-ingress"
}

variable "kong_ingress_namespace" {
  type        = string
  description = "Kong ingress namespace."
  default     = "kong-ingress"
}

variable "kong_ingress_create_namespace" {
  type        = bool
  description = "Create kong-ingress namespace."
  default     = true
}

variable "kong_ingress_wait_for_jobs" {
  type        = bool
  description = "Kong ingress wait for jobs paramater."
  default     = true
}

variable "kong_ingress_chart_repository" {
  type        = string
  description = "Kong ingress chart repository url."
  default     = "https://charts.konghq.com"
}

variable "kong_ingress_chart_name" {
  type        = string
  description = "Kong ingress chart name."
  default     = "kong"
}

variable "kong_ingress_chart_version" {
  type        = string
  description = "Kong ingress chart version."
  default     = "2.23.0"
}

variable "kong_ingress_install_timeout" {
  type        = number
  description = "Kong ingress chart install timeout."
  default     = 600
}

variable "kong_ingress_custom_values_yaml" {
  type        = string
  description = "Kong ingress chart values.yaml path."
  default     = "kong_ingress.yaml.tfpl"
}

variable "kong_loadbalancer_annotations" {
  type        = string
  description = "Kong ingress loadbalancer annotations."
  default     = "{}"
}

variable "kong_ingress_aws_eip_ids" {
  type        = string
  description = "Kong ingress loadbalancer AWS static ip ids. Can also accept a comma separated values such as eip1, eip2, eip3"
  default     = ""
}

variable "kong_ingress_aws_subnet_ids" {
  type        = string
  description = "Kong ingress loadbalancer AWS subnet ids. Can also accept a comma separated values such as s1, s2, s3"
  default     = ""
}