building_block                = "obsrv"
env                           = "dev"
region                        = "us-east-2"
availability_zones            = ["us-east-2a", "us-east-2b", "us-east-2c"]
timezone                      = "UTC"
create_kong_ingress           = "true"
create_vpc                    = "true"
create_velero_user            = "true"
vpc_id                        = ""
eks_nodes_subnet_ids          = [""]
eks_master_subnet_ids         = [""]
velero_aws_access_key_id      = ""
velero_aws_secret_access_key  = ""

# cluster sizing

eks_node_group_instance_type  = ["t2.xlarge"]
eks_node_group_capacity_type  = "ON_DEMAND"
eks_node_group_scaling_config = {
  desired_size = 5
  max_size = 5
  min_size = 1
}

# Disk node size in gb
eks_node_disk_size            = 30

# Image Tags
command_service_image_tag         = "1.0.0-GA"
web_console_image_tag             = "1.0.0-GA"
dataset_api_image_tag             = "1.0.2-GA"
flink_image_tag                   = "1.0.1-GA"
secor_image_tag                   = "1.0.0-GA"
superset_image_tag                = "3.0.2"

enable_lakehouse                = false
flink_lakehouse_image_tag       = "1.0.1"
