variable "env" {
    type        = string
    description = "Environment name. All resources will be prefixed with this value."
    default     = "dev"
}

variable "building_block" {
    type        = string
    description = "Building block name. All resources will be prefixed with this value."
    default     = "obsrv"
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

variable "vnet_cidr" {
    type        = list(string)
    description = "Azure vnet CIDR range."
    default     = ["10.0.0.0/16"]
}

variable "aks_subnet_cidr" {
    type        = list(string)
    description = "Azure AKS subnet CIDR range."
    default     = ["10.0.0.0/22"]
}

variable "aks_subnet_service_endpoints" {
    type        = list(string)
    description = "Azure AKS subnet service endpoints."
    default     = ["Microsoft.Sql", "Microsoft.Storage"]
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

variable "aks_nodepool_name" {
    type        = string
    description = "AKS node pool name."
    default     = "aksnodepool1"
}

variable "aks_node_count" {
    type        = number
    description = "AKS node count."
    default     = 5
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

variable "flink_checkpoint_store_type" {
    type        = string
    description = "Flink checkpoint store type."
    default     = "azure"
}