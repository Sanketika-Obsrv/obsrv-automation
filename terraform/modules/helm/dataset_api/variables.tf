variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}

variable "dataset_api_release_name" {
  type        = string
  description = "Dataset service helm release name."
  default     = "dataset-api"
}

variable "dataset_api_namespace" {
  type        = string
  description = "Dataset service namespace."
  default     = "dataset-api"
}

variable "dataset_api_chart_path" {
  type        = string
  description = "Dataset service chart path."
  default     = "dataset-api-helm-chart"
}

variable "dataset_api_create_namespace" {
  type        = bool
  description = "Create Dataset service namespace."
  default     = true
}

variable "dataset_api_custom_values_yaml" {
  type = string
  default = "dataset_api.yaml.tfpl"
}

variable "dataset_api_wait_for_jobs" {
  type        = bool
  description = "Dataset service wait for jobs paramater."
  default     = true
}

variable "dataset_api_install_timeout" {
  type        = number
  description = "Dataset service chart install timeout."
  default     = 1200
}

variable "dataset_api_postgres_database" {
  type        = string
  description = "Dataset service postgres database"
  default     = "dataset_api"
}

variable "dataset_api_postgres_username" {
  type = string
  description = "Dataset service postgres username"
  default = "dataset_api_user"
}

variable "dataset_api_postgres_user_password" {
  type = string
  description = "Dataset service postgres password"
}

variable "dataset_api_chart_depends_on" {
  type        = any
  description = "List of helm release names that this chart depends on."
  default     = ""
}

variable "dataset_api_container_registry" {
  type        = string
  description = "Container registry. For example docker.io/obsrv"
}

variable "dataset_api_image_name" {
  type        = string
  description = "Dataset api image name."
  default     = "obsrv-api-service"
}

variable "dataset_api_image_tag" {
  type        = string
  description = "Dataset api image tag."
}

variable "dataset_api_sa_annotations" {
  type        = string
  description = "Service account annotations for dataset api service account."
  default     = "serviceAccountName: default"
}