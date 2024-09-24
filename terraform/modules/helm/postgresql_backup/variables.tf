variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}

variable "postgresql_backup_release_name" {
  type        = string
  description = "Postgresql backup helm release name."
  default     = "postgresql-backup"
}

variable "postgresql_backup_namespace" {
  type        = string
  description = "Postgresql backup namespace."
}

variable "postgresql_backup_create_namespace" {
  type        = bool
  description = "Create Postgresql backup namespace."
  default     = true
}

variable "postgresql_backup_wait_for_jobs" {
  type        = bool
  description = "Postgresql backup wait for jobs parameter."
  default     = true
}

variable "postgresql_backup_install_timeout" {
  type        = number
  description = "Postgresql backup chart install timeout."
  default     = 600
}

variable "postgresql_backup_chart_path" {
  type        = string
  description = "Postgresql backup helm chart path."
  default     = "postgresql-backup-helm-chart"
}

variable "postgresql_backup_custom_values_yaml" {
  type        = string
  description = "Superset helm chart values.yaml path."
  default     = "postgresql_backup.yaml.tfpl"
}

variable "postgresql_backup_sa_annotations" {
  type        = string
  description = "Service account annotations for postgresql backup service account."
  default     = "serviceAccountName: default"
}

variable "postgresql_backup_image_repository" {
  type        = string
  description = "Postgresql backup image repository."
  default     = "sanketikahub/postgresql-backup"
}

variable "postgresql_backup_image_tag" {
  type        = string
  description = "Postgresql backup image tag."
  default     = "1.0.5-GA"
}

variable "postgresql_backup_cron_schedule" {
  type        = string
  description = "Postgresql cronjob schedule. Defaults to midnight everyday."
  default     = "00 00 * * *"
}

variable "postgresql_backup_postgres_user" {
  type        = string
  description = "Postgresql admin user name."
}

variable "postgresql_backup_postgres_host" {
  type        = string
  description = "Postgresql host url."
}

variable "postgresql_backup_postgres_password" {
  type        = string
  description = "Postgresql password."
}

variable "postgresql_backup_s3_bucket" {
  type        = string
  description = "Postgresql backup s3 bucket name."
  default     = ""
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

variable "cloud_store_provider" {
  type = string
  description = "value of cloud backup service. eg. s3, gcs etc"
  default = "s3"
}

variable "postgresql_backup_gcs_bucket" {
  type        = string
  description = "Postgresql backup gcs bucket name."
  default     = ""
}
