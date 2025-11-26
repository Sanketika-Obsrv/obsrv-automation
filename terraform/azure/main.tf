terraform {
  backend "azurerm" {}
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    local = {
      source = "hashicorp/local"
      version  = "~> 2.0"
    }
    helm = {
      source = "hashicorp/helm"
      version  = "~> 2.0"
    }
  }
}

provider "azurerm" {
  features {}
}

module "network" {
  source          = "../modules/azure/network"
  building_block        = var.building_block
  env                   = var.env
  location              = var.location
  resource_group_name = var.resource_group_name
  additional_tags       = var.additional_tags
  vnet_cidr            = var.vnet_cidr
  aks_subnet_cidr      = var.aks_subnet_cidr
  create_vnet          = var.create_vnet
  existing_vnet_name   = var.existing_vnet_name
  existing_aks_subnet_name = var.existing_aks_subnet_name
  create_kong_ingress_ip = var.create_kong_ingress_ip
  kong_ingress_alloc_id  = var.kong_ingress_alloc_id
}

module "aks" {
  source              = "../modules/azure/aks"
  resource_group_name = var.resource_group_name
  building_block        = var.building_block
  env                   = var.env
  location              = var.location
  aks_version         = var.aks_version
  aks_nodepool_name   = var.aks_nodepool_name
  aks_node_count      = var.aks_node_count
  aks_node_size       = var.aks_node_size
  additional_tags     = var.additional_tags
  aks_subnet_id       = module.network.aks_subnet_id
  depends_on = [ module.network, module.storage ]
}

module "storage" {
  source              = "../modules/azure/storage"
  resource_group_name = var.resource_group_name
  building_block        = var.building_block
  env                   = var.env
  location              = var.location
  storage_account_name = var.storage_account_name
  azure_storage_tier       = var.azure_storage_tier
  azure_storage_replication = var.azure_storage_replication
  checkpoint_container     = var.checkpoint_container
  velero_backup_container  = var.velero_backup_container
  additional_tags          = var.additional_tags
}

provider "helm" {
  kubernetes {
    host                   = module.aks.kubernetes_host
    client_certificate     = module.aks.client_certificate
    client_key             = module.aks.client_key
    cluster_ca_certificate = module.aks.cluster_ca_certificate
  }
}