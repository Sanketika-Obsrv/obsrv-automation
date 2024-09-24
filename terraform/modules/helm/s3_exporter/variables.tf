variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}

variable "s3_exporter_release_name" {
  type        = string
  description = "S3 exporter helm release name."
  default     = "s3-exporter"
}

variable "s3_exporter_namespace" {
  type        = string
  description = "S3 exporter namespace."
}

variable "s3_exporter_create_namespace" {
  type        = bool
  description = "Create S3 exporter namespace."
  default     = true
}

variable "s3_exporter_wait_for_jobs" {
  type        = bool
  description = "S3 exporter wait for jobs parameter."
  default     = true
}

variable "s3_exporter_install_timeout" {
  type        = number
  description = "S3 exporter chart install timeout."
  default     = 600
}

variable "s3_exporter_chart_path" {
  type        = string
  description = "S3 exporter helm chart path."
  default     = "s3-exporter-helm-chart"
}

variable "s3_exporter_custom_values_yaml" {
  type        = string
  description = "Superset helm chart values.yaml path."
  default     = "s3_exporter.yaml.tfpl"
}

variable "s3_exporter_sa_annotations" {
  type        = string
  description = "Service account annotations for s3 exporter service account."
  default     = "serviceAccountName: default"
}

variable "s3_exporter_image_repository" {
  type        = string
  description = "S3 exporter image repository"
  default     = "ribbybibby/s3-exporter"
}

variable "s3_exporter_image_tag" {
  type        = string
  description = "S3 exporter image tag"
  default     = "latest"
}

variable "s3_region" {
  type        = string
  description = "S3 region to be used for storage metrics"
  default     = "us-east-2"
}