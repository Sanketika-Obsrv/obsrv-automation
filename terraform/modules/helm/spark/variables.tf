variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}

variable "spark_release_name" {
  type        = string
  description = "spark helm release name."
  default     = "spark"
}

variable "spark_namespace" {
  type        = string
  description = "spark namespace."
  default     = "spark"
}

variable "spark_chart_path" {
  type        = string
  description = "spark helm chart path."
  default     = "spark-helm-chart"
}

variable "spark_chart_install_timeout" {
  type        = number
  description = "spark helm chart install timeout."
  default     = 3000
}

variable "spark_create_namespace" {
  type        = bool
  description = "Create spark namespace."
  default     = true
}

variable "spark_wait_for_jobs" {
  type        = bool
  description = "spark wait for jobs paramater."
  default     = true
}

variable "spark_chart_custom_values_yaml" {
  type        = string
  description = "spark helm chart values.yaml path."
  default     = "spark.yaml.tfpl"
}

variable "spark_chart_dependency_update" {
  type        = bool
  description = "spark helm chart dependency update."
  default     = true
}

variable "spark_install_timeout" {
  type        = number
  description = "spark chart install timeout."
  default     = 3000
}

variable "spark_image_repository" {
  type        = string
  description = "spark image repository."
}

variable "spark_image_tag" {
  type        = string
  description = "spark image tag."
}

variable "spark_metrics_topic" {
  type        = string
  description = "spark metrics topic"
  default     = "spark.stats"
}

variable "spark_metrics_version" {
  type        = string
  description = "spark metrics version"
  default     = "1.0.0"
}

variable "docker_registry_secret_name" {
  type         = string
  description  = "Docker registry secret name"
}

variable "create_service_account" {
  type            = bool
  description     = "create service account or not?"
  default         = true
}

variable "spark_sa_annotations" {
  type            = string
  description     = "service account annotations"
}
variable "kubernetes_storage_class" {
  type            = string
  description     = "kubernetes storage class"
}
variable "postgresql_obsrv_username" {
  type            = string
  description     = "postgresql username"
}
variable "postgresql_obsrv_password" {
  type            = string
  description     = "postgresql password"
}
variable "postgresql_obsrv_database" {
  type            = string
  description     = "postgres database"
}
variable "s3_bucket" {
  type            = string
  description     = "s3 bucket"
}
variable "druid_cluster_release_name" {
  type            = string
  description     = "druid cluster release name"
}
variable "druid_cluster_namespace" {
  type            = string
  description     = "druid cluster namespace"
}
variable "redis_release_name" {
  type            = string
  description     = "redis release name"
}
variable "redis_namespace" {
  type            = string
  description     = "redis namespace"
}
variable "cloud_provider" {
  type            = string
  description     = "cloud provider"
}


variable "encryption_key" {
  type            = string
  description = "key for credential encryption."
}

variable "s3_region" {
  type            = string
  description     = "region of cloud provider"
}

variable "spark_sa_role" {
  type           = string
  description    = "spark service account role"
}

variable "cloud_storage_prefix" {
  type = string
  description = "Cloud storage type"
  default = "s3"
}