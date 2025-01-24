building_block               = "obsrv-helm"
env                          = "test"
region                       = "us-east-2"
availability_zones           = ["us-east-2a", "us-east-2b", "us-east-2c"]
timezone                     = "UTC"
create_kong_ingress          = "true"
create_vpc                   = "true"
create_velero_user           = "true"
vpc_id                       = ""
eks_nodes_subnet_ids         = [""]
eks_master_subnet_ids        = [""]


# cluster sizing
eks_endpoint_private_access  = false
eks_node_group_instance_type = ["t2.2xlarge"]
eks_node_group_capacity_type = "ON_DEMAND"
eks_node_group_scaling_config = {
  desired_size = 3
  max_size     = 3
  min_size     = 1
}
# Disk node size in gb
eks_node_disk_size = 100

create_s3_buckets = true
s3_buckets = {
  "s3_bucket"                 = "",
  "velero_storage_bucket"     = "",
  "checkpoint_storage_bucket" = "",
  "s3_backups_bucket"         = ""
}
