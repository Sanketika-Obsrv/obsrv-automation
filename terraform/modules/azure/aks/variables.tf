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
  default     = "East US 2"
}

variable "additional_tags" {
  type        = map(string)
  description = "Additional tags for the resources. These tags will be applied to all the resources."
  default     = {}
}

variable "aks_nodepool_name" {
  type        = string
  description = "AKS node pool name."
  default     = "aksnodepool1"
}

variable "aks_node_count" {
  type        = number
  description = "AKS node count."
  default     = 4
}

variable "aks_node_size" {
  type        = string
  description = "AKS node size."
  default     = "Standard_D2s_v4"
}

variable "aks_cluster_identity" {
  type        = string
  description = "AKS cluster identity."
  default     = "SystemAssigned"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name to create the AKS cluster."
}