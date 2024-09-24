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
variable "resource_group_name" {
  type        = string
  description = "Resource group name for AKS, subnets etc"
}

variable "storage_account_name" {
  type        = string
  description = "Storage account name"
}