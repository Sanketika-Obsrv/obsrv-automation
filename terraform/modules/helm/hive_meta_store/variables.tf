variable "hms_image" {
  type        = object({ name = string, tag = string, registry = string, pullPolicy = string })
  description = "Trino image metadata"
  default = {
    name       = "hms"
    tag        = "1.0.3"
    pullPolicy = "IfNotPresent"
    registry   = "sanketikahub"
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

variable "hms_service" {
  type        = object({ type = string, port = number })
  description = "HMS service metadata"
  default     = { type = "ClusterIP", port = 9083 }
}

locals {
  default_hms_db_metadata = {}
  default_hadoop_metadata = {
    "fs.s3a.impl"                   = "org.apache.hadoop.fs.s3a.S3AFileSystem"
    "fs.s3a.connection.ssl.enabled" = "false"
  }
}

variable "hms_db_metadata" {
  type        = map(string)
  description = "HMS database connection details"
}

variable "hadoop_metadata" {
  type        = map(string)
  description = "Hadoop core site configuration"
}

locals {
  env_vars             = merge(local.default_hms_db_metadata, var.hms_db_metadata)
  hadoop_configuration = merge(local.default_hadoop_metadata, var.hadoop_metadata)
}