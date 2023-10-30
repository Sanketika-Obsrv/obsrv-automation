output "azurerm_storage_account_name" {
  value = azurerm_storage_account.storage_account.name
}

output "azurerm_storage_account_key" {
  value = azurerm_storage_account.storage_account.primary_access_key
}

output "azurerm_storage_container" {
  value = azurerm_storage_container.storage_container.name
}