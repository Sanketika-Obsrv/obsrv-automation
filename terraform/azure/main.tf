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
}

module "aks" {
  source              = "../modules/azure/aks"
  resource_group_name = module.network.resource_group_name
  building_block        = var.building_block
  env                   = var.env
  location              = var.location
  depends_on = [ module.network, module.storage ]
}

module "storage" {
  source              = "../modules/azure/storage"
  resource_group_name = module.network.resource_group_name
  building_block        = var.building_block
  env                   = var.env
  location              = var.location
}

provider "helm" {
  kubernetes {
    host                   = module.aks.kubernetes_host
    client_certificate     = module.aks.client_certificate
    client_key             = module.aks.client_key
    cluster_ca_certificate = module.aks.cluster_ca_certificate
  }
}

module "unified_helm" {
  source                      = "../modules/helm/unified_helm"
  building_block              = var.building_block
  env                         = var.env
  depends_on                  = [ module.storage,module.aks ]
  azure_storage_account_key   = module.storage.azurerm_storage_account_key
  azure_storage_account_name  = module.storage.azurerm_storage_account_name
  azure_storage_container     = module.storage.azurerm_storage_container
}