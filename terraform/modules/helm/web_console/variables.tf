variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
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
  default     = "sanketikahub"
}

variable "web_console_image_tag" {
  type        = string
  description = "web console image tag."
}

variable "web_console_image_name" {
  type        = string
  description = "web console image name."
  default = "sb-obsrv-web-console"
}

variable "web_console_configs" {
  type = map
  description = "Web console config variables. See below commented code for values that need to be passed"
}

variable "web_console_install_timeout" {
  type        = number
  description = "Web console chart install timeout."
  default     = 1200
}