variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}

variable "kafka_exporter_release_name" {
  type        = string
  description = "Kafka exporter helm release name."
  default     = "kafka-exporter"
}

variable "kafka_exporter_namespace" {
  type        = string
  description = "Kafka exporter namespace."
  default     = "kafka"
}

variable "kafka_exporter_chart_path" {
  type        = string
  description = "Kafka exporter chart path."
  default     = "kafka-exporter-helm-chart"
}

variable "kafka_exporter_create_namespace" {
  type        = bool
  description = "Create kakfa exporter namespace."
  default     = true
}

variable "kafka_exporter_wait_for_jobs" {
  type        = bool
  description = "Kafka exporter wait for jobs paramater."
  default     = true
}

variable "kafka_exporter_custom_values_yaml" {
  type = string
  default = "kafka_exporter.yaml.tfpl"
}

variable "kafka_exporter_install_timeout" {
  type        = number
  description = "Kafka exporter chart install timeout."
  default     = 1200
}

variable "kafka_exporter_chart_depends_on" {
  type        = any
  description = "List of helm release names that this chart depends on."
  default     = ""
}