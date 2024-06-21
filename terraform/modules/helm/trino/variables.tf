
variable "trino_image" {
  type        = object({ name = string, tag = string, registry = string, pullPolicy = string })
  description = "Trino image metadata"
  default = {
    name       = "trinodb/trino"
    tag        = "latest"
    pullPolicy = "IfNotPresent"
    registry   = ""
  }
}
variable "trino_namespace" {
  type        = string
  description = "Trino namespace"
  default     = "hudi"
}
variable "trino_create_namespace" {
  type        = bool
  description = "Create Trino namespace."
  default     = true
}
variable "trino_wait_for_jobs" {
  type        = bool
  description = "Trino wait for jobs paramater."
  default     = false
}

variable "trino_chart_install_timeout" {
  type        = number
  description = "Trino chart install timeout."
  default     = 900
}

variable "trino_custom_values_yaml" {
  type        = string
  description = "Trino chart values.yaml path."
  default     = "trino.yaml.tfpl"
}

variable "trino_workers_count" {
  default     = 1
  description = "Number of trino workers"
  type        = number
}

variable "trino_release_name" {
  type        = string
  description = "Trino release name"
  default     = "trino"
}

variable "trino_chart_path" {
  type        = string
  description = "Trino helm chart path."
  default     = "trino-helm-chart"
}
variable "trino_chart_depends_on" {
  type        = any
  description = "List of helm release names that this chart depends on."
  default     = ""
}
variable "trino_service" {
  type        = object({ type = string, port = number })
  description = "Trino service metadata"
  default     = { type = "ClusterIP", port = 8080 }
}
variable "trino_lakehouse_metadata" {
  type        = map(string)
  description = "Trino lakehouse config"
}
locals {
  default_lakehouse_metadata = {
    "connector.name"      = "hudi"
    "hive.metastore.uri"  = "thrift://hms-metastore-app.hudi.svc:9083"
    "hive.s3.ssl.enabled" = "false"
  }
}
locals {
  catalogs = {
    lakehouse = merge(var.trino_lakehouse_metadata, local.default_lakehouse_metadata)
  }
}
