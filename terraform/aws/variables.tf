variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}

variable "region" {
  type        = string
  description = "AWS region to create the resources."
}

variable "availability_zones" {
  type        = list(string)
  description = "AWS Availability Zones."
}

variable "timezone" {
  type        = string
  description = "Timezone property to backup the data"
}

variable "create_vpc" {
  type = bool
  description = "Toggle to create to a vpc"
}
variable "eks_nodes_subnet_ids" {
  type = list(string)
  description = "The VPC's subnet id which will be used to create the EKS node groups"
  default = [""]
}
variable "eks_master_subnet_ids" {
  type = list(string)
  description = "The VPC's subnet id which will be used to create the EKS cluster"
  default = [""]
}

variable "create_velero_user" {
  type = bool
  description = "Toggle to create a velero user"
}
variable "velero_aws_access_key_id" {
  type = string
  description = "AWS Access key to access bucket"
  default = ""
}
variable "velero_aws_secret_access_key" {
  type = string
  description = "AWs Secret access key to access bucket"
  default = "" 
}
variable "service_type" {
  type = string
  description = "Kubernetes service type either NodePort or LoadBalancer. It is LoadBalancer by default"
  default = "LoadBalancer"
}
variable "cluster_logs_enabled" {
  type = bool
  description = "Toggle to enable eks cluster logs"
  default = true
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
}

variable "flink_container_registry" {
  type        = string
  description = "Container registry. For example docker.io/obsrv"
  default     = "sanketikahub"
}

variable "flink_image_tag" {
   type        = string
   description = "Flink kubernetes service name."
}

variable "web_console_configs" {
  type = map
  description = "Web console config variables. See below commented code for values that need to be passed"
  default = {
    port                               = "3000"
    app_name                           = "obsrv-web-console"
    prometheus_url                     = "http://monitoring-kube-prometheus-prometheus.monitoring:9090"
    react_app_grafana_url              = "http://localhost:80"
    react_app_superset_url             = "http://localhost:8081"
    https                              = "false"
    react_app_version                  = "v1.2.0"
    generate_sourcemap                 = "false"
  }
}

variable "web_console_image_tag" {
  type        = string
  description = "web console image tag."
}

variable "web_console_image_repository" {
  type        = string
  description = "Container registry. For example docker.io/obsrv"
  default     = "sanketikahub"
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

variable "flink_unified_pipeline_release_names" {
  description = "Create release names"
  type        = map(string)
  default = {
    unified-pipeline = "unified-pipeline"
    master-data-processor = "master-data-processor"
  }
}

variable "unified_pipeline_enabled" {
  description = "Toggle to deploy unified pipeline"
  type = bool
  default = true
}

variable "command_service_image_tag" {
  type        = string
  description = "CommandService image tag."
}

variable "superset_image_tag" {
  type        = string
  description = "Superset image tag."
}

variable "secor_image_tag" {
  type        = string
  description = "secor image version"
}


variable "hudi_namespace" {
  type        = string
  default     = "hudi"
  description = "Apache Hudi namespace"
}

variable "hudi_prefix_path" {
  type        = string
  description = "Hudi prefix path"
  default     = "hudi"
}

variable "enable_lakehouse" {
  type        = bool
  description = "Toggle to install hudi components (hms, trino and flink job)"
}

variable "lakehouse_host" {
  type        = string
  description = "Lakehouse Host"
  default     = "http://trino.hudi.svc.cluster.local"
}

variable "lakehouse_port" {
  type        = string
  description = "Trino port"
  default     = "8080"
}

variable "lakehouse_catalog" {
  type        = string
  description = "Lakehouse Catalog name"
  default     = "lakehouse"
}

variable "lakehouse_schema" {
  type        = string
  description = "Lakehouse Schema name"
  default     = "hms"
}

variable "lakehouse_default_user" {
  type        = string
  description = "Lakehouse default user"
  default     = "admin"
}


variable "flink_image_name" {
  type        = string
  description = "Flink image name."
  default = "lakehouse-connector"
}

variable "flink_lakehouse_image_tag" {
  type        = string
  description = "Flink lakehouse image tag."
  default = "1.0.0"
}
