variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}

variable "submit_ingestion_release_name" {
  type        = string
  description = "Submit ingestion helm release name."
  default     = "submit-ingestion"
}

variable "submit_ingestion_namespace" {
  type        = string
  description = "Submit ingestion namespace."
  default     = "submit-ingestion"
}

variable "submit_ingestion_chart_path" {
  type        = string
  description = "Submit ingestion chart path."
  default     = "submit-ingestion-helm-chart"
}

variable "submit_ingestion_chart_install_timeout" {
  type        = number
  description = "Submit ingestion chart install timeout."
  default     = 600
}

variable "submit_ingestion_create_namespace" {
  type        = bool
  description = "Create submit_ingestion namespace."
  default     = true
}

variable "submit_ingestion_wait_for_jobs" {
  type        = bool
  description = "Submit ingestion wait for jobs paramater."
  default     = true
}

variable "submit_ingestion_chart_custom_values_yaml" {
  type        = string
  description = "Submit ingestion chart values.yaml path."
  default     = "submit_ingestion.yaml.tfpl"
}

variable "submit_ingestion_custom_values_yaml" {
  type        = string
  description = "Submit ingestion chart values.yaml path."
  default     = "submit_ingestion.yaml.tfpl"
}

variable "submit_ingestion_chart_depends_on" {
  type        = any
  description = "List of helm release names that this chart depends on."
  default     = ""
}

variable "druid_cluster_release_name" {
  type        = any
  description = "druid release name"
}

variable "druid_cluster_namespace" {
  type        = any
  description = "druid namespace"
}