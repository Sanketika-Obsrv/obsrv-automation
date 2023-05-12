variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}

variable "flink_release_name" {
  type        = string
  description = "Flink helm release name."
  default     = "merged-pipeline"
}

variable "flink_namespace" {
  type        = string
  description = "Flink namespace."
}

variable "flink_chart_path" {
  type        = string
  description = "Flink chart path."
  default     = "flink-helm-chart"
}

variable "flink_chart_install_timeout" {
  type        = number
  description = "Flink chart install timeout."
  default     = 900
}

variable "flink_create_namespace" {
  type        = bool
  description = "Create flink namespace."
  default     = true
}

variable "flink_wait_for_jobs" {
  type        = bool
  description = "Flink wait for jobs paramater."
  default     = false
}

variable "flink_custom_values_yaml" {
  type        = string
  description = "Flink chart values.yaml path."
  default     = "flink.yaml.tfpl"
}

variable "flink_kubernetes_service_name" {
  type        = string
  description = "Flink kubernetes service name."
  default     = "merged-pipeline"
}

variable "flink_container_registry" {
  type        = string
  description = "Container registry. For example docker.io/obsrv"
}

variable "flink_image_name" {
  type        = string
  description = "Flink image name."
  default     = "obsrv-core-pipeline"
}

variable "flink_image_tag" {
  type        = string
  description = "Flink image tag."
}

variable "flink_checkpoint_store_type" {
  type        = string
  description = "Flink checkpoint store type."
}

variable "checkpoint_base_url" {
  type        = string
  description = "checkpoint storage base url."
  default     = ""
}

variable "flink_chart_depends_on" {
  type        = any
  description = "List of helm release names that this chart depends on."
  default     = ""
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
}

variable "redis_namespace" {
  type        = string
  description = "Namespace of Redis installation."
  default     = "redis"
}

variable "redis_release_name" {
  type        = string
  description = "Release name for Redis installation."
  default     = "obsrv-redis"
}

variable "s3_access_key" {
  type        = string
  description = "S3 access key for flink checkpoints."
  default     = ""
}

variable "s3_secret_key" {
  type        = string
  description = "S3 secret key for flink checkpoints."
  default     = ""
}

variable "azure_storage_account_name" {
  type        = string
  description = "Azure storage account name for flink checkpoints."
  default     = ""
}

variable "azure_storage_account_key" {
  type        = string
  description = "Azure storage account key for flink checkpoints."
  default     = ""
}

variable "flink_sa_annotations" {
  type        = string
  description = "Service account annotations for flink service account."
  default     = "serviceAccountName: default"
}