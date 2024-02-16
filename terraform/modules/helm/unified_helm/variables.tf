variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}

variable "obsrv_release_name" {
  type        = string
  description = "obsrv helm release name."
  default     = "obsrv"
}

variable "obsrv_namespace" {
  type        = string
  description = "obsrv namespace."
  default     = "obsrv"
}

variable "obsrv_chart_path" {
  type        = string
  description = "obsrv helm chart path."
  default     = "obsrv"
}

variable "obsrv_chart_install_timeout" {
  type        = number
  description = "obsrv helm chart install timeout."
  default     = 1800
}

variable "obsrv_create_namespace" {
  type        = bool
  description = "Create obsrv namespace."
  default     = true
}

variable "obsrv_wait_for_jobs" {
  type        = bool
  description = "obsrv wait for jobs paramater."
  default     = true
}

variable "obsrv_custom_values_yaml" {
  type        = string
  description = "obsrv helm chart values.yaml path."
  default     = "obsrv.yaml.tfpl"
}

variable "obsrv_install_timeout" {
  type        = number
  description = "obsrv chart install timeout."
  default     = 1800
}

variable "obsrv_chart_depends_on" {
  type        = any
  description = "List of helm release names that this chart depends on."
  default     = ""
}
variable "azure_storage_container" {
  type = string
  description = "Storage container"
}
variable "azure_storage_account_key" {
  type = string
  default = "Storage account key"
}
variable "azure_storage_account_name" {
  type = string
  default = "Storage account name"
}