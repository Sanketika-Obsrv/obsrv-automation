output "azurerm_storage_container" {
  value = azurerm_storage_container.storage_container.name
}
output "checkpoint_storage_container" {
  value = azurerm_storage_container.checkpoint_storage_container.name
}
output "velero_storage_container" {
  value = azurerm_storage_container.velero_storage_container.name
}