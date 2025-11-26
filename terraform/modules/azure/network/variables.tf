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

variable "additional_tags" {
    type        = map(string)
    description = "Additional tags for the resources. These tags will be applied to all the resources."
    default     = {}
}

variable "vnet_cidr" {
    type        = list(string)
    description = "Azure vnet CIDR range."
    default     = ["10.0.0.0/23"]
}

variable "aks_subnet_cidr" {
  type        = list(string)
  description = "Azure AKS subnet CIDR range."
  default     = ["10.0.0.0/23"]
}

variable "aks_subnet_service_endpoints" {
  type        = list(string)
  description = "Azure AKS subnet service endpoints."
  default     = ["Microsoft.Sql", "Microsoft.Storage"]
}


variable "resource_group_name" {
  type        = string
  description = "Resource group name to create the AKS cluster."
}

variable "create_vnet" {
  type        = bool
  description = "Whether to create a new VNet. If false, an existing subnet name must be provided in existing_aks_subnet_name."
  default     = true
}

variable "existing_vnet_name" {
  type        = string
  description = "Name of an existing virtual network to use (optional)."
  default     = ""
}

variable "existing_aks_subnet_name" {
  type        = string
  description = "Name of an existing subnet to use for AKS (required when create_vnet = false)."
  default     = ""
}

variable "create_kong_ingress_ip" {
  type        = string
  description = "Create a Public IP for Kong ingress (string 'true' or 'false' to match root var usage)."
  default     = "false"
}

variable "kong_ingress_alloc_id" {
  type        = string
  description = "If using an existing public IP, provide its name or id."
  default     = ""
}
