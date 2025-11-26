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

variable "additional_tags" {
  type        = map(string)
  description = "Additional tags for the resources. These tags will be applied to all the resources."
  default     = {}
}

variable "azure_storage_tier" {
  type        = string
  description = "Azure storage tier - Standard / Premium."
  default     = "Standard"
}

variable "azure_storage_replication" {
  type        = string
  description = "Azure storage replication - LRS / ZRS / GRS etc."
  default     = "LRS"
}

variable "checkpoint_container" {
  type        = string
  description = "Container in the storage account to use for checkpoints"
  default     = "checkpointing"
}

variable "velero_backup_container" {
  type        = string
  description = "Container in the storage account to use for Velero backups"
  default     = "velero"
}

variable "vnet_cidr" {
  type        = list(string)
  description = "VNet CIDR ranges"
  default     = ["10.0.0.0/23"]
}

variable "aks_subnet_cidr" {
  type        = list(string)
  description = "AKS subnet CIDR ranges"
  default     = ["10.0.0.0/23"]
}

variable "aks_version" {
  type        = string
  description = "AKS cluster version"
  default     = "1.28"
}

variable "aks_nodepool_name" {
  type        = string
  description = "AKS node pool name."
  default     = "aksnodepool1"
}

variable "aks_node_count" {
  type        = number
  description = "AKS node count."
  default     = 3
}

variable "aks_node_size" {
  type        = string
  description = "AKS node size."
  default     = "Standard_D4s_v3"
}

variable "create_kong_ingress_ip" {
  type        = string
  description = "Whether to create a public IP for Kong ingress (string to keep parity with existing tfvars usage)."
  default     = "false"
}

variable "kong_ingress_alloc_id" {
  type        = string
  description = "Existing public IP resource id or name to use for Kong ingress."
  default     = ""
}

variable "kong_ingress_alloc_rg" {
  type        = string
  description = "Resource group name where the existing PIP exists (optional)."
  default     = ""
}

variable "kong_ingress_loadBalancerIP" {
  type        = string
  description = "Optionally provide an explicit IP to use as service.loadBalancerIP for Kong."
  default     = ""
}

variable "create_vnet" {
  type        = bool
  description = "Whether to create a new Azure Virtual Network (VNet). If false, existing VNet/subnet will be used via existing_vnet_name and existing_aks_subnet_name."
  default     = true
}

variable "existing_vnet_name" {
  type        = string
  description = "If using existing VNet, provide its name."
  default     = ""
}

variable "existing_aks_subnet_name" {
  type        = string
  description = "If using existing subnet for AKS, provide the subnet name."
  default     = ""
}