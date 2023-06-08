variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
  default     = "obsrv"
  validation {
    condition     = length(var.building_block) > 0
    error_message = "The building block name must not be empty."
  }
  validation {
    condition     = can(regex("[a-zA-Z0-9\\-]+", var.building_block))
    error_message = "The building block name can only contain alphanumeric characters and dashes."
  }
}

variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
  default     = "dev"
}

## Google Cloud Platform

variable "project" {
  description = "The project ID where all resources will be launched."
  type        = string
  default     = "obsrv-gcp"
}

variable "region" {
  description = "The region for the network. If the cluster is regional, this must be the same region. Otherwise, it should be the region of the zone."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The zone for the cluster. If the cluster is regional, this should be one of the zones in the region. Otherwise, this should be the same zone as the region."
  type        = string
  default     = "us-central1-a"
}


## VPC

variable "vpc_cidr_block" {
  type        = string
  description = "VPC CIDR range"
  default     = "10.0.0.0/16"
}

variable "vpc_secondary_cidr_block" {
  description = "The IP address range of the VPC's secondary address range in CIDR notation. A prefix of /16 is recommended. Do not use a prefix higher than /27."
  type        = string
  default     = "10.1.0.0/16"
}

variable "auto_assign_public_ip" {
  type        = bool
  description = "Auto assign public ip's to instances in this subnet"
  default     = true
}

variable "public_subnetwork_secondary_range_name" {
  description = "The name associated with the pod subnetwork secondary range, used when adding an alias IP range to a VM instance. The name must be 1-63 characters long, and comply with RFC1035. The name must be unique within the subnetwork."
  type        = string
  default     = "public-cluster"
}

variable "public_services_secondary_range_name" {
  description = "The name associated with the services subnetwork secondary range, used when adding an alias IP range to a VM instance. The name must be 1-63 characters long, and comply with RFC1035. The name must be unique within the subnetwork."
  type        = string
  default     = "public-services"
}

variable "public_services_secondary_cidr_block" {
  description = "The IP address range of the VPC's public services secondary address range in CIDR notation. A prefix of /16 is recommended. Do not use a prefix higher than /27. Note: this variable is optional and is used primarily for backwards compatibility, if not specified a range will be calculated using var.secondary_cidr_block, var.secondary_cidr_subnetwork_width_delta and var.secondary_cidr_subnetwork_spacing."
  type        = string
  default     = null
}

variable "private_services_secondary_cidr_block" {
  description = "The IP address range of the VPC's private services secondary address range in CIDR notation. A prefix of /16 is recommended. Do not use a prefix higher than /27. Note: this variable is optional and is used primarily for backwards compatibility, if not specified a range will be calculated using var.secondary_cidr_block, var.secondary_cidr_subnetwork_width_delta and var.secondary_cidr_subnetwork_spacing."
  type        = string
  default     = null
}

variable "secondary_cidr_subnetwork_width_delta" {
  description = "The difference between your network and subnetwork's secondary range netmask; an /16 network and a /20 subnetwork would be 4."
  type        = number
  default     = 4
}

variable "secondary_cidr_subnetwork_spacing" {
  description = "How many subnetwork-mask sized spaces to leave between each subnetwork type's secondary ranges."
  type        = number
  default     = 0
}

variable "igw_cidr" {
  type        = list(string)
  description = "Internet gateway CIDR range."
  default     = ["0.0.0.0/0"]
}

variable "gcs_service_account_name" {
  description = "The name of the custom service account used for GCS. This parameter is limited to a maximum of 28 characters."
  type        = string
  default     = "gcs-object-admin"
}

variable "gcs_service_account_description" {
  description = "A description of the custom service account used for the GKE cluster."
  type        = string
  default     = "GCS Service Account managed by Terraform"
}

## GKE Cluster Variables

variable "gke_cluster_location" {
  description = "The location (region or zone) of the GKE cluster."
  type        = string
  default     = "us-central1"
}

variable "gke_master_ipv4_cidr_block" {
  description = "The IP range in CIDR notation (size must be /28) to use for the hosted master network. This range will be used for assigning internal IP addresses to the master or set of masters, as well as the ILB VIP. This range must not overlap with any other ranges in use within the cluster's network."
  type        = string
  default     = "10.5.0.0/28"
}

variable "cluster_service_account_name" {
  description = "The name of the custom service account used for the GKE cluster. This parameter is limited to a maximum of 28 characters."
  type        = string
  default     = "terraform"
}

variable "cluster_service_account_description" {
  description = "A description of the custom service account used for the GKE cluster."
  type        = string
  default     = "GKE Cluster Service Account managed by Terraform"
}

variable "enable_vertical_pod_autoscaling" {
  description = "Enable vertical pod autoscaling"
  type        = string
  default     = true
}

variable "enable_workload_identity" {
  description = "Enable Workload Identity on the cluster"
  default     = true
  type        = bool
}

variable "override_default_node_pool_service_account" {
  description = "When true, this will use the service account that is created for use with the default node pool that comes with all GKE clusters"
  type        = bool
  default     = true
}

variable "kubernetes_storage_class" {
  type        = string
  description = "Storage class name for the GKE cluster"
  default     = "pd-ssd"
}

variable "kubernetes_storage_class_raw" {
  type        = string
  description = "Storage class name in raw format, they use a different notation than the GKE cluster"
  default     = "standard-rwo"
}

variable "druid_deepstorage_type" {
  type        = string
  description = "Druid deep strorage."
  default     = "google"
}

variable "flink_checkpoint_store_type" {
  type        = string
  description = "Flink checkpoint store type."
  default     = "gcs"
}

### kubectl config

variable "kubectl_config_path" {
  description = "The path to the kubectl config file."
  type        = string
  default     = ".kube/config"
}

# variable "kubectl_config_context" {
#   description = "The name of the kubectl config context to use."
#   type        = string
#   default     = "gke_"
# }

# Helm Specific Configs
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

variable "flink_image_name" {
  type        = string
  description = "Flink image name."
  default     = "merged-pipeline"
}

variable "flink_image_tag" {
  type        = string
  description = "Flink kubernetes service name."
  default     = "build_deploy_v2"
}

variable "flink_release_name" {
  type        = list(string)
  description = "Flink helm release name."
  default     = [ "merged-pipeline","master-data-processor" ]
}

variable "dataset_api_sa_iam_role_name" {
  type        = string
  description = "IAM role name for dataset api service account."
  default     = "dataset-api-sa-iam-role"
}

variable "dataset_api_namespace" {
  type        = string
  description = "Dataset service namespace."
  default     = "dataset-api"
}

variable "flink_sa_iam_role_name" {
  type        = string
  description = "IAM role name for flink service account."
  default     = "flink-sa-iam-role"
}

variable "flink_namespace" {
  type        = string
  description = "Flink namespace."
  default     = "flink"
}

variable "druid_raw_sa_iam_role_name" {
  type        = string
  description = "IAM role name for druid raw service account."
  default     = "druid-raw-sa-iam-role"
}

variable "druid_raw_namespace" {
  type        = string
  description = "Druid raw namespace."
  default     = "druid-raw"
}

variable "secor_sa_iam_role_name" {
  type        = string
  description = "IAM role name for secor service account."
  default     = "secor-sa-iam-role"
}

variable "secor_namespace" {
  type        = string
  description = "Secor namespace."
  default     = "secor"
}

variable "velero_sa_iam_role_name" {
  type        = string
  description = "IAM role name for secor service account."
  default     = "velero-sa-iam-role"
}

variable "velero_namespace" {
  type        = string
  description = "Velero namespace."
  default     = "velero"
}