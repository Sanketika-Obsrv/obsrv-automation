variable "project" {
  description = "The project ID where the bucket needs to be created"
  type        = string
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}

variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "region" {
  description = "The region for cloud storage bucket"
  type        = string
}

variable "uniform_bucket_level_access" {
  description = "Enable uniform bucket level access"
  type        = bool
  default     = true
}