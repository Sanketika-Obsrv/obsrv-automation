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

variable "region" {
  type        = string
  description = "AWS region to create the resources."
  default     = "us-east-2"
}

variable "flink_checkpoint_store_type" {
  type        = string
  description = "Flink checkpoint store type."
  default     = "s3"
}

variable "druid_deepstorage_type" {
  type        = string
  description = "Druid deep strorage type."
  default     = "s3"
}

variable "kubernetes_storage_class" {
  type        = string
  description = "Storage class name for the Kubernetes cluster"
  default     = "gp2"
}

variable "dataset_api_container_registry" {
  type        = string
  description = "Container registry. For example docker.io/obsrv"
  default     = "sanketikahub"
}

variable "dataset_api_image_tag" {
  type        = string
  description = "Dataset api image tag."
  default     = "1.0.4"
}

variable "flink_container_registry" {
  type        = string
  description = "Container registry. For example docker.io/obsrv"
  default     = "sanketikahub"
}

variable "flink_image_tag" {
   type        = string
   description = "Flink kubernetes service name."
   default     = "release-0.5.0_RC10"
}

variable "storage_class" {
  type        = string
  description = "Storage Class"
  default     = "gp2"
}
variable "flink_release_names" {
  description = "Create release names"
  type        = map(string)
  default = {
    extractor       = "extractor"
    preprocessor    = "preprocessor"
    denormalizer    = "denormalizer"
    transformer     = "transformer"
    druid-router    = "druid-router"
    master-data-processor = "master-data-processor"
  }
}

variable "flink_merged_pipeline_release_names" {
  description = "Create release names"
  type        = map(string)
  default = {
    merged-pipeline = "merged-pipeline"
    master-data-processor = "master-data-processor"
  }
}

variable "merged_pipeline_enabled" {
  description = "Toggle to deploy merged pipeline"
  type = bool
  default = true
}
variable "postgresql_service_name" {
  type        = string
  description = "Postgresql service name."
}