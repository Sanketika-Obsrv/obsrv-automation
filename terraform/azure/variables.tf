variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
  default     = "dev"
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
  default     = "obsrv"
}

variable "kubernetes_storage_class" {
    type        = string
    description = "Storage class name for the AKS cluster"
    default     = "default"
}

variable "druid_deepstorage_type" {
    type        = string
    description = "Druid deep strorage type."
    default     = "azure"
}

variable "flink_checkpoint_store_type" {
    type        = string
    description = "Flink checkpoint store type."
    default     = "azure"
}

variable "dataset_api_container_registry" {
  type        = string
  description = "Container registry. For example docker.io/obsrv"
  default     = "sanketikahub"
}

variable "dataset_api_image_tag" {
  type        = string
  description = "Dataset api image tag."
  default     = "1.0.0"
}

variable "flink_container_registry" {
  type        = string
  description = "Container registry. For example docker.io/obsrv"
  default     = "manjudr"
}

variable "flink_image_tag" {
   type        = string
   description = "Flink kubernetes service name."
   default     = "1.1.0"
}

variable "command_service_image_tag" {
  type        = string
  description = "CommandService image tag."
  default     = "1.0.0"
}