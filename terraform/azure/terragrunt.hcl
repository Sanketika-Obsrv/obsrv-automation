remote_state {
  backend = "azurerm"
  config = {
    resource_group_name  = get_env("AZURE_TERRAFORM_BACKEND_RG")
    storage_account_name = get_env("AZURE_TERRAFORM_BACKEND_STORAGE_ACCOUNT")
    container_name       = get_env("AZURE_TERRAFORM_BACKEND_CONTAINER")
    key                  = "${path_relative_to_include()}/terraform.tfstate"
  }
}

# inputs = {
#   region                         = "us-east-2"
#   env                            = "dev"
#   building_block                 = "obsrv"
#   kubernetes_storage_class       = "gp2"
#   druid_deepstorage_type         = "s3"
#   flink_checkpoint_store_type    = "s3"
#   dataset_api_container_registry = "sanketikahub"
#   dataset_api_image_tag          = "1.0.4"
#   flink_container_registry       = "manjudr"
#   flink_image_tag                = "2.1"
# }