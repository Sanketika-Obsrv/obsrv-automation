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
}

module "aks" {
  source              = "../modules/azure/aks"
  resource_group_name = var.resource_group_name
  building_block        = var.building_block
  env                   = var.env
  location              = var.location
  depends_on = [ module.network, module.storage ]
}

module "storage" {
  source              = "../modules/azure/storage"
  resource_group_name = var.resource_group_name
  building_block        = var.building_block
  env                   = var.env
  location              = var.location
  storage_account_name = var.storage_account_name
}

# When azure_storage_account_key is empty, read the key via managed identity / service principal
# (Contributor role required — granted by setup-azure-installer-identity.sh).
# When the key is explicitly provided in tfvars, the data source is skipped entirely.
data "azurerm_storage_account" "obsrv" {
  count               = var.azure_storage_account_key == "" ? 1 : 0
  name                = var.storage_account_name
  resource_group_name = var.resource_group_name
}

locals {
  storage_account_key = var.azure_storage_account_key != "" ? var.azure_storage_account_key : data.azurerm_storage_account.obsrv[0].primary_access_key
}

output "storage_account_key" {
  value     = local.storage_account_key
  sensitive = true
}

provider "helm" {
  kubernetes {
    host                   = module.aks.kubernetes_host
    client_certificate     = module.aks.client_certificate
    client_key             = module.aks.client_key
    cluster_ca_certificate = module.aks.cluster_ca_certificate
  }
}