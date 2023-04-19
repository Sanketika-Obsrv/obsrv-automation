variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}

variable "kafka_release_name" {
  type        = string
  description = "Kafka helm release name."
  default     = "kafka"
}

variable "kafka_namespace" {
  type        = string
  description = "Kafka namespace."
  default     = "kafka"
}

variable "kafka_chart_path" {
  type        = string
  description = "Kafka helm chart path."
  default     = "kafka-helm-chart"
}

variable "kafka_chart_install_timeout" {
  type        = number
  description = "Kafka helm chart install timeout."
  default     = 3000
}

variable "kafka_create_namespace" {
  type        = bool
  description = "Create kafka namespace."
  default     = true
}

variable "kafka_wait_for_jobs" {
  type        = bool
  description = "Kafka wait for jobs paramater."
  default     = true
}

variable "kafka_chart_custom_values_yaml" {
  type        = string
  description = "Kafka helm chart values.yaml path."
  default     = "kafka.yaml.tfpl"
}

variable "kafka_chart_dependecy_update" {
  type        = bool
  description = "Kafka helm chart dependency update."
  default     = true
}

variable "kafka_input_topic" {
  type        = string
  description = "Kafka input topic."
  default     = "telemetry.denorm"
}

variable "kafka_output_telemetry_route_topic" {
  type        = string
  description = "Kafka output telemetry route topic"
  default     = "druid.events.telemetry"
}

variable "kafka_output_summary_route_topic" {
  type        = string
  description = "Kafka output summary route topic"
  default     = "druid.events.summary"
}

variable "kafka_output_failed_topic" {
  type        = string
  description = "Kafka output failed topic"
  default     = "telemetry.failed"
}

variable "kafka_output_duplicate_topic" {
  type        = string
  description = "Kafka output duplicate topic"
  default     = "telemetry.duplicate"
}

variable "kafka_install_timeout" {
  type        = number
  description = "Kafka chart install timeout."
  default     = 1200
}