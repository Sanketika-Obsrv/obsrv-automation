
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
  description = "Dataset service chart path."
  default     = "trino-helm-chart"
}

variable "trino_catalogs" {
  type        = map(string)
  description = "Trino catalogs metadata"
  default = {
    lakehouse = <<EOT
      connector.name=hudi
      hive.metastore.uri=thrift://192.168.1.17:9083
      hive.s3.aws-access-key=FUnv52wOP4UFjqaWxlYD
      hive.s3.aws-secret-key=z6W2aRxdw2uLseMMdhhURMjniIeUeQLxOmormmwi
      hive.s3.endpoint=http://192.168.1.17:4566
      hive.s3.ssl.enabled=false
    EOT
  }
}

variable "trino_chart_depends_on" {
  type        = any
  description = "List of helm release names that this chart depends on."
  default     = ""
}
