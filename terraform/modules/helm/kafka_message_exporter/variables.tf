variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}

variable "kafka_message_exporter_release_name" {
  type        = string
  description = "Kafka message exporter helm release name."
  default     = "kafka-message-exporter"
}

variable "kafka_message_exporter_namespace" {
  type        = string
  description = "Kafka message exporter namespace."
  default     = "kafka"
}

variable "kafka_message_exporter_wait_for_jobs" {
  type        = bool
  description = "Kafka message exporter wait for jobs parameter."
  default     = true
}

variable "kafka_message_exporter_install_timeout" {
  type        = number
  description = "Kafka message exporter chart install timeout."
  default     = 600
}

variable "kafka_message_exporter_chart_path" {
  type        = string
  description = "Kafka message exporter helm chart path."
  default     = "kafka-message-exporter-helm-chart"
}

variable "kafka_message_exporter_custom_values_yaml" {
  type        = string
  description = "Superset helm chart values.yaml path."
  default     = "kafka_message_exporter.yaml.tfpl"
}

variable "kafka_message_exporter_sa_annotations" {
  type        = string
  description = "Service account annotations for postgresql backup service account."
  default     = "serviceAccountName: default"
}

variable "kafka_message_exporter_image_repository" {
  type        = string
  description = "Kafka message exporter image repository."
  default     = "sanketikahub/kafka-message-exporter"
}

variable "kafka_message_exporter_image_tag" {
  type        = string
  description = "Kafka message exporter image tag."
  default     = "1.0.0-GA"
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

variable "kafka_host" {
  type        = string
  description = "Kafka service name with port."
  default     = "kafka-headless.kafka.svc.cluster.local:9092"
}

variable "spark_metrics_topic" {
  type        = string
  description = "Spark metrics topic"
  default     = "spark.stats"
}
