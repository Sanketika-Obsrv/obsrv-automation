variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}

variable "druid_cluster_release_name" {
  type        = string
  description = "Druid cluster helm release name."
  default     = "druid-raw"
}

variable "druid_cluster_namespace" {
  type        = string
  description = "Druid namespace."
}

variable "druid_cluster_chart_path" {
  type        = string
  description = "Druid cluster chart path."
  default     = "druid-raw-cluster-helm-chart"
}

variable "druid_cluster_chart_install_timeout" {
  type        = number
  description = "Druid cluster chart install timeout."
  default     = 3000
}

variable "druid_cluster_create_namespace" {
  type        = bool
  description = "Create druid cluster namespace."
  default     = true
}

variable "druid_cluster_wait_for_jobs" {
  type        = bool
  description = "Druid cluster wait for jobs paramater."
  default     = true
}

variable "druid_cluster_custom_values_yaml" {
  type        = string
  description = "Druid cluster chart values.yaml path."
  default     = "druid_raw_cluster.yaml.tfpl"
}

variable "druid_raw_database" {
  type        = string
  description = "Druid database."
  default     = "druid_raw"
}

variable "druid_raw_user" {
  type        = string
  description = "Druid user name."
  default     = "druid_raw"
}

variable "druid_raw_user_password" {
  type        = string
  description = "Druid password."
}

variable "druid_worker_capacity" {
  type        = number
  description = "Druid middle manager worker capacity."
  default     = 2
}

variable "druid_deepstorage_type" {
  type        = string
  description = "Druid deep strorage type."
}

variable "kubernetes_storage_class" {
  type        = string
  description = "Storage class name for the Kubernetes cluster"
}

variable "druid_raw_cluster_chart_depends_on" {
  type        = any
  description = "List of helm release names that this chart depends on."
  default     = ""
}

variable "s3_bucket" {
  type        = string
  description = "S3 bucket name for druid deepstore."
  default     = ""
}

variable "s3_access_key" {
  type        = string
  description = "S3 access key for druid deepstore."
  default     = ""
}

variable "s3_secret_key" {
  type        = string
  description = "S3 secret key for druid deepstore."
  default     = ""
}

variable "azure_storage_account_name" {
  type        = string
  description = "Azure storage account name for druid deepstore."
  default     = ""
}

variable "azure_storage_account_key" {
  type        = string
  description = "Azure storage account key for druid deepstore."
  default     = ""
}

variable "azure_storage_container" {
  type        = string
  description = "Azure storage account container name for druid deepstore."
  default     = ""
}

variable "gcs_bucket" {
  type        = string
  description = "GCS bucket name for druid deepstore."
  default     = ""
}

variable "druid_raw_sa_annotations" {
  type        = string
  description = "Service account annotations for druid raw service account."
  default     = "serviceAccountName: default"
}