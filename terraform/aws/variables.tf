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
  default     = "sanketikahub/obsrv-core"
}

variable "flink_image_tag" {
   type        = string
   description = "Flink kubernetes service name."
   default     = "release-0.5.0_RC10"
}

variable "storage_class" {
  type        = string
  description = "Storage Class"
  default     = "default"
}

variable "web_console_configs" {
  type = map
  description = "Web console config variables. See below commented code for values that need to be passed"
  default = {
    port                               = "3000"
    app_name                           = "obsrv-web-console"
    prometheus_url                     = "http://monitoring-kube-prometheus-prometheus.monitoring:9090"
    react_app_grafana_url              = "http://localhost:8081"
    react_app_superset_url             = "http://localhost:80"
    https                              = "false"
    react_app_version                  = "v1.2.0"
    generate_sourcemap                 = "false"
  } 
}

variable "web_console_image_tag" {
  type        = string
  description = "web console image tag."
  default = "release-0.5.0_RC4"
}

variable "web_console_image_repository" {
  type        = string
  description = "Container registry. For example docker.io/obsrv"
  default     = "sanketikahub"
}