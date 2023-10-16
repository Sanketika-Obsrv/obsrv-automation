variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "command_service_release_name" {
  type        = string
  description = "CommandService helm release name."
  default     = "command-api"
}

variable "command_service_namespace" {
  type        = string
  description = "CommandService namespace."
  default     = "command-service"
}

variable "command_service_chart_path" {
  type        = string
  description = "CommandService chart path."
  default     = "command-service-helm-chart"
}

variable "command_service_chart_install_timeout" {
  type        = number
  description = "CommandService chart install timeout."
  default     = 900
}

variable "command_service_create_namespace" {
  type        = bool
  description = "Create command-service namespace."
  default     = true
}

variable "command_service_wait_for_jobs" {
  type        = bool
  description = "Command Service wait for jobs paramater."
  default     = true
}

variable "command_service_custom_values_yaml" {
  type        = string
  description = "Command Service chart values.yaml path."
  default     = "command-service.yaml.tfpl"
}

variable "command_service_chart_depends_on" {
  type        = any
  description = "List of helm release names that this chart depends on."
  default     = ""
}

variable "command_service_image_repository" {
  type        = string
  description = "CommandService image name."
  default     = "sanketikahub/flink-command-service"
}

variable "command_service_image_tag" {
  type        = string
  description = "CommandService image tag."
  default     = "1.0.0"
}

variable "postgresql_obsrv_username" {
  type        = string
  description = "Postgresql obsrv username."
  default     = "obsrv"
}

variable "postgresql_obsrv_user_password" {
  type        = string
  description = "Postgresql obsrv user password."
}

variable "postgresql_obsrv_database" {
  type        = string
  description = "Postgresql obsrv database."
  default     = "obsrv"
}

variable "flink_namespace" {
  type        = string
  description = "Flink installation namespace"
  default     = "flink"
}

variable "docker_registry_secret_name" {
  type        = string
  description = "Kubernetes secret name to pull images from private docker registry."
}