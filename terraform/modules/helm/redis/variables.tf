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
  default     = "17.3.11"
}

variable "redis_install_timeout" {
  type        = number
  description = "Redis chart install timeout."
  default     = 1200
}

variable "redis_release_name" {
  type        = string
  description = "Redis helm release name."
  default     = "obsrv-redis"
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

variable "redis_maxmemory_eviction_policy" {
  type        = string
  description = "Redis maxmemory eviction policy"
  default     = "volatile-ttl"
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

variable "redis_replica_persistence_size" {
  type        = string
  description = "Redis disk path for persistence"
  default     = "2Gi"
}

variable "redis_custom_values_yaml" {
  type        = string
  description = "Redis chart values.yaml path."
  default     = "redis.yaml.tfpl"
}