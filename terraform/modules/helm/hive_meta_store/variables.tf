variable "hms_image" {
  type        = object({ name = string, tag = string, registry = string, pullPolicy = string })
  description = "Trino image metadata"
  default = {
    name       = "maheshkg/hive-metastore"
    tag        = "latest"
    pullPolicy = "IfNotPresent"
    registry   = ""
  }
}

variable "hms_namespace" {
  type        = string
  description = "HMS namespace"
  default     = "hudi"
}

variable "hms_create_namespace" {
  type        = bool
  description = "Create HMS namespace."
  default     = true
}

variable "hms_wait_for_jobs" {
  type        = bool
  description = "HMS wait for jobs paramater."
  default     = false
}

variable "hms_chart_install_timeout" {
  type        = number
  description = "HMS chart install timeout."
  default     = 900
}

variable "hms_custom_values_yaml" {
  type        = string
  description = "HMS chart values.yaml path."
  default     = "hms.yaml.tfpl"
}

variable "hms_release_name" {
  type        = string
  description = "HMS release name"
  default     = "hms"
}

variable "hms_chart_path" {
  type        = string
  description = "HMS helm chart path."
  default     = "hms-helm-chart"
}

variable "hms_chart_depends_on" {
  type        = any
  description = "List of helm release names that this chart depends on."
  default     = ""
}

variable "hms_replica_count" {
  type        = number
  description = "HMS replica count"
  default     = 1
}

variable "hms_db_metadata" {
  type        = map(string)
  description = "HMS database connection details"
  default = {
    "DATABASE_HOST"     = "192.168.1.17"
    "DATABASE_DB"       = "postgres"
    "DATABASE_USER"     = "postgres"
    "DATABASE_PASSWORD" = "postgres"
  }
}

variable "hms_object_store_metadata" {
  type        = map(string)
  description = "HMS object store connection metadata"
  default = {
    "AWS_ACCESS_KEY_ID"     = "test"
    "AWS_SECRET_ACCESS_KEY" = "testSecret"
    "S3_ENDPOINT_URL"       = "http://192.168.1.17:4566"
    "S3_BUCKET"             = "obsrv"
    "S3_PREFIX"             = ""
  }
}

variable "hms_service" {
  type        = object({ type = string, port = number })
  description = "HMS service metadata"
  default     = { type = "ClusterIP", port = 9083 }
}

locals {
  env_vars = merge(var.hms_db_metadata, var.hms_object_store_metadata)
}


