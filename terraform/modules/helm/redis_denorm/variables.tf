variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}

variable "redis_chart_repository" {
  type        = string
  description = "Redis chart repository url."
  default     = "https://charts.bitnami.com/bitnami"
}

variable "redis_chart_name" {
  type        = string
  description = "Redis chart name."
  default     = "redis"
}

variable "redis_chart_version" {
  type        = string
  description = "Redis chart version."
  default     = "17.11.3"
}

variable "redis_install_timeout" {
  type        = number
  description = "Redis chart install timeout."
  default     = 1200
}

variable "redis_release_name" {
  type        = string
  description = "Redis helm release name."
  default     = "obsrv-denorm-redis"
}

variable "redis_namespace" {
  type        = string
  description = "Redis namespace."
  default     = "redis"
}

variable "redis_create_namespace" {
  type        = bool
  description = "Create redis namespace."
  default     = true
}

variable "redis_wait_for_jobs" {
  type        = bool
  description = "Redis wait for jobs paramater."
  default     = true
}

variable "redis_master_maxmemory" {
  type        = string
  description = "Redis maxmemory assigned for the master"
  default     = "1024mb"
}

variable "redis_replica_maxmemory" {
  type        = string
  description = "Redis maxmemory assigned for the replica"
  default     = "1024mb"
}
variable "redis_replica_persistence_size" {
  type        = string
  description = "Redis disk path for persistence"
  default     = "2Gi"
}


variable "redis_maxmemory_eviction_policy" {
  type        = string
  description = "Redis maxmemory eviction policy"
  default     = "noeviction"
}

variable "redis_persistence_path" {
  type        = string
  description = "Redis disk path for persistence"
  default     = "/data"
}

variable "redis_master_persistence_size" {
  type        = string
  description = "Redis disk path for persistence"
  default     = "2Gi"
}

variable "redis_custom_values_yaml" {
  type        = string
  description = "Redis chart values.yaml path."
  default     = "redis.yaml.tfpl"
}

variable "redis_backup_image_repository" {
  type        = string
  description = "Redis backup image repository."
  default     = "sanketikahub/redis-backup"
}

variable "redis_backup_image_tag" {
  type        = string
  description = "Redis backup image tag."
  default     = "1.0.4-GA"
}

variable "redis_backup_cron_schedule" {
  type        = string
  description = "Redis cronjob schedule. Defaults to midnight everyday."
  default     = "00 00 * * *"
}

variable "redis_backup_s3_bucket" {
  type        = string
  description = "Redis backup s3 bucket name."
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

variable "redis_backup_sa_annotations" {
  type        = string
  description = "Service account annotations for redis backup service account."
  default     = "serviceAccountName: default"
}

variable "cloud_store_provider" {
  type        = string
  description = "value of cloud backup service. eg. s3, gcs etc"
  default     = "s3"
}

variable "redis_backup_gcs_bucket" {
  type        = string
  description = "Redis backup gcs bucket name."
  default     = ""
}

variable "azure_storage_account_name" {
  type        = string
  description = "Azure Storage Account Name"
  default     = ""
}

variable "azure_storage_account_key" {
  type        = string
  description = "Azure Storage Account Key"
  default     = ""
}

variable "redis_backup_azure_bucket" {
  type        = string
  description = "Redis Backup Azure Bucket"
  default     = ""
}
