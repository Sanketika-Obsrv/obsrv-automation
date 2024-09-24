variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}

variable "system_rules_ingestor_release_name" {
  type        = string
  description = "system_rules_ingestor service helm release name."
  default     = "system-rules-ingestor"
}

variable "system_rules_ingestor_namespace" {
  type        = string
  description = "system_rules_ingesto service namespace."
  default     = "system-rules-ingestor"
}

variable "system-rules-ingestor_chart_path" {
  type        = string
  description = "system_rules_ingestor service chart path."
  default     = "system-rules-ingestor-helm-chart"
}

variable "system_rules_ingestor_create_namespace" {
  type        = bool
  description = "Create system_rules_ingestorservice namespace."
  default     = true
}

variable "system_rules_ingestor_custom_values_yaml" {
  type = string
  default = "system_rules_ingestor.yaml.tfpl"
}

variable "system_rules_ingestor_wait_for_jobs" {
  type        = bool
  description = "system_rules_ingestor service wait for jobs paramater."
  default     = true
}

variable "system_rules_ingestor_install_timeout" {
  type        = number
  description = "system_rules_ingestorservice chart install timeout."
  default     = 1200
}


variable "system_rules_ingestor_depends_on" {
  type        = any
  description = "List of helm release names that this chart depends on."
  default     = ""
}
variable "system_rules_ingestor_container_registry" {
  type        = string
  description = "Container registry. For example docker.io/obsrv"
  default = "sanketikahub"
}

variable "system_rules_ingestor_image_name" {
  type        = string
  description = "Dataset api image name."
  default = "system-rules-ingestor"
}

variable "system_rules_ingestor_image_tag" {
  type        = string
  description = "system_rules_ingestor image tag."
  default = "1.0.0"
}
variable "service_account_name" {
  type        = string
  description = "Name of the service account for the application."
  default     = "system-rules-ingestor"
}

# variable "dataset_service_url" {
#   type        = string
#   description = "URL for the dataset service."
#   default     = "http://dataset-api-service.dataset-api.svc:3000"
# }
