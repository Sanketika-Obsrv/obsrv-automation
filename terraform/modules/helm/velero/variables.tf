variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}

variable "velero_release_name" {
  type        = string
  description = "Velero helm release name."
  default     = "velero"
}

variable "velero_namespace" {
  type        = string
  description = "Velero namespace."
  default     = "velero"
}

variable "velero_chart_install_timeout" {
  type        = number
  description = "Velero chart install timeout."
  default     = 3000
}

variable "velero_create_namespace" {
  type        = bool
  description = "Create velero namespace."
  default     = true
}

variable "velero_wait_for_jobs" {
  type        = bool
  description = "Velero wait for jobs paramater."
  default     = true
}

variable "velero_chart_repository" {
  type        = string
  description = "Velero chart repository url."
  default     = "https://vmware-tanzu.github.io/helm-charts"
}

variable "velero_chart_name" {
  type        = string
  description = "Velero chart name."
  default     = "velero"
}

variable "velero_chart_version" {
  type        = string
  description = "Velero chart version."
  default     = "3.1.6"
}

variable "velero_install_timeout" {
  type        = number
  description = "Velero chart install timeout."
  default     = 1200
}

variable "aws_velero_custom_values_yaml" {
  type        = string
  description = "Velero chart values.yaml path for AWS cloud."
  default     = "aws-velero.tfpl.yaml"
}

variable "gcp_velero_custom_values_yaml" {
  type        = string
  description = "Velero chart values.yaml path for GCP cloud."
  default     = "gcp-velero.tfpl.yaml"
}

variable "velero_aws_access_key_id" {
  type        = string
  description = "Velero S3 bucker AWS access key."
  default     = ""
}

variable "velero_aws_secret_access_key" {
  type        = string
  description = "Velero S3 bucker AWS secret key."
  default     = ""
}

variable "cloud_provider" {
  type        = string
  description = "Cloud provider name which velero will use to store backups."
}

variable "velero_backup_bucket" {
  type        = string
  description = "S3 bucket name to store backups."
}

variable "velero_backup_bucket_region" {
  type        = string
  description = "S3 bucket region in which the backups will be stored."
}

variable "velero_sa_iam_role_name" {
  type        = string
  description = "Service Account IAM Role Name"
}

variable "velero_sa_name" {
  type        = string
  description = "Service Account Name"
  default     = "velero-sa"
}

variable "velero_sa_annotations" {
  type        = string
  description = "Service Account Annotations."
  default     = "serviceAccountName: default"
}

variable "gcp_project_id" {
  type        = string
  description = "Google Project ID, if the provider is gcp"
}