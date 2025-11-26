data "azurerm_subscription" "current" {}

locals {
    common_tags = {
      Environment = "${var.env}"
      BuildingBlock = "${var.building_block}"
    }
    subid = split("-", "${data.azurerm_subscription.current.subscription_id}")
    environment_name = "${var.building_block}-${var.env}"
}


resource "azurerm_virtual_network" "vnet" {
  count               = var.create_vnet ? 1 : 0
  name                = "${local.environment_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_cidr
  tags = merge(
      local.common_tags,
      var.additional_tags
      )
}

resource "azurerm_subnet" "aks_subnet" {
  count                = var.create_vnet ? 1 : 0
  name                 = "${local.environment_name}-aks"
  resource_group_name  = var.resource_group_name
  virtual_network_name = var.create_vnet ? azurerm_virtual_network.vnet[0].name : var.existing_vnet_name
  address_prefixes     = var.aks_subnet_cidr
  service_endpoints    = var.aks_subnet_service_endpoints
}

data "azurerm_subnet" "existing" {
  count = var.create_vnet ? 0 : 1
  name  = var.existing_aks_subnet_name
  virtual_network_name = var.existing_vnet_name
  resource_group_name  = var.resource_group_name
}

# Optional: reserve a static Public IP for Kong ingress
resource "azurerm_public_ip" "kong" {
  count               = var.create_kong_ingress_ip == "true" ? 1 : 0
  name                = "${local.environment_name}-kong-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = merge(local.common_tags, var.additional_tags)
}