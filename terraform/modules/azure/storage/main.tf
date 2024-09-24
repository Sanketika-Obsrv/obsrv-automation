data "azurerm_subscription" "current" {}
locals {
    environment_name = "${var.building_block}-${var.env}"
}

resource "azurerm_storage_container" "storage_container" {
  name                  = "${local.environment_name}"
  storage_account_name  = var.storage_account_name
  container_access_type = "private"
}

resource "azurerm_storage_container" "checkpoint_storage_container" {
  name                  = "${local.environment_name}-${var.checkpoint_container}"
  storage_account_name  = var.storage_account_name
  container_access_type = "private"
}

resource "azurerm_storage_container" "velero_storage_container" {
  name                  = "${local.environment_name}-${var.velero_backup_container}"
  storage_account_name  = var.storage_account_name
  container_access_type = "private"
}