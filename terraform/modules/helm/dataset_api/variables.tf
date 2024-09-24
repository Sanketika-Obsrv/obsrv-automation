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
}
variable "service_type" {
  type = string
  description = "Kubernetes service type either NodePort or LoadBalancer. It is NodePort by default"
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

variable "postgresql_obsrv_database" {
  type        = string
  description = "obsrv postgres database"
}

variable "postgresql_obsrv_username" {
  type = string
  description = "obsrv postgres username"
  default = "obsrv"
}

variable "postgresql_obsrv_user_password" {
  type = string
  description = "obsrv user postgres password"
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
}

variable "dataset_api_image_tag" {
  type        = string
  description = "Dataset api image tag."
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

variable "dataset_api_sa_annotations" {
  type        = string
  description = "Service account annotations for dataset api service account."
  default     = "serviceAccountName: default"
}

variable "denorm_redis_namespace" {
  type        = string
  description = "Namespace of Redis installation."
  default     = "redis"
}

variable "denorm_redis_release_name" {
  type        = string
  description = "Release name for Redis installation."
  default     = "obsrv-denorm-redis"
}

variable "dedup_redis_release_name" {
  type        = string
  description = "Redis helm release name."
  default     = "obsrv-dedup-redis"
}

variable "dedup_redis_namespace" {
  type        = string
  description = "Redis namespace."
  default     = "redis"
}

variable "druid_cluster_release_name" {
  type        = string
  description = "Druid cluster helm release name."
  default     = "druid-raw"
}

variable "druid_cluster_namespace" {
  type        = string
  description = "Druid cluster namespace."
  default     = "druid-raw"
}

variable "command_service_namespace" {
  type        = string
  description = "Command service namespace."
  default     = "command-api"
}

variable "command_service_release_name" {
  type        = string
  description = "Command service helm release name."
  default     = "command-api"
}

variable "s3_bucket" {
  type        = string
  description = "S3 bucket name for dataset api exhaust."
  default     = ""
}
variable "grafana_url" {
  type        = string
  description = "grafana url"
  default     = "http://monitoring-grafana.monitoring.svc:80"
}

variable "encryption_key" {
  type        = string
  description = "key for credential encryption."
}

variable "storage_provider" {
  type      = string
  description = "storage provider name e.g: aws, azure, gcp"
}

variable "s3_region" {
  type        = string
  description = "AWS region to create the resources. e.g.: us-east-2"
}

variable "enable_lakehouse" {
  type        = bool
  description = "Toggle to install hudi components (hms, trino and flink job)"
}

variable "lakehouse_host" {
  type        = string
  description = "Lakehouse Host"
  default     = "http://trino.hudi.svc.cluster.local"
}

variable "lakehouse_port" {
  type        = string
  description = "Trino port"
  default     = "8080"
}

variable "lakehouse_catalog" {
  type        = string
  description = "Lakehouse Catalog name"
  default     = "lakehouse"
}

variable "lakehouse_schema" {
  type        = string
  description = "Lakehouse Schema name"
  default     = "hms"
}

variable "lakehouse_default_user" {
  type        = string
  description = "Lakehouse default user"
  default     = "admin"
}