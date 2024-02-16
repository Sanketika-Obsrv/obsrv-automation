variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}

variable "location" {
    type        = string
    description = "Azure location to create the resources."
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