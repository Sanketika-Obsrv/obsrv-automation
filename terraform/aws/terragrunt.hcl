remote_state {
  backend = "s3"
  config = {
    bucket  = get_env("AWS_TERRAFORM_BACKEND_BUCKET_NAME")
    region  = get_env("AWS_TERRAFORM_BACKEND_BUCKET_REGION")
    key     = "${path_relative_to_include()}/terraform.tfstate"
    encrypt = true
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