# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED MODULE PARAMETERS
# These parameters must be supplied when consuming this module.
# ---------------------------------------------------------------------------------------------------------------------

variable "project" {
  description = "The name of the GCP Project where all resources will be launched."
  type        = string
}

variable "name" {
  description = "The name of the custom service account. This parameter is limited to a maximum of 28 characters."
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL MODULE PARAMETERS
# These parameters have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------

variable "description" {
  description = "The description of the custom service account."
  type        = string
  default     = ""
}

variable "service_account_roles" {
  description = "Additional roles to be added to the service account."
  type        = list(string)
  default     = []
}

variable "google_service_account_key_path" {
  description = "The path to the service account key file."
  type        = string
  default     = ""
}

variable "sa_namespace" {
  description = "The namespace of the GKE service account."
  type        = string
  default     = ""
}

variable "sa_name" {
  description = "The name of the GKE service account."
  type        = string
  default     = ""
}

variable "sa_key_store_bucket" {
  description = "The name of the GCS bucket where the service account key will be stored."
  type        = string
  default     = ""
}