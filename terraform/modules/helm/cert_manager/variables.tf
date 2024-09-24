variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}

variable "cert_manager_release_name" {
  type        = string
  description = "Cert manager ingress helm release name."
  default     = "cert-manager"
}

variable "cert_manager_namespace" {
  type        = string
  description = "Cert manager ingress namespace."
  default     = "cert-manager"
}

variable "cert_manager_create_namespace" {
  type        = bool
  description = "Create cert-manager namespace."
  default     = true
}

variable "cert_manager_wait_for_jobs" {
  type        = bool
  description = "Cert manager ingress wait for jobs paramater."
  default     = true
}

variable "cert_manager_chart_repository" {
  type        = string
  description = "Cert manager ingress chart repository url."
  default     = "https://charts.jetstack.io"
}

variable "cert_manager_chart_name" {
  type        = string
  description = "Cert manager ingress chart name."
  default     = "cert-manager"
}

variable "cert_manager_chart_version" {
  type        = string
  description = "Cert manager ingress chart version."
  default     = "v1.12.2"
}

variable "cert_manager_install_timeout" {
  type        = number
  description = "Cert manager ingress chart install timeout."
  default     = 600
}

variable "cert_manager_custom_values_yaml" {
  type        = string
  description = "Cert manager ingress chart values.yaml path."
  default     = "cert_manager.yaml"
}