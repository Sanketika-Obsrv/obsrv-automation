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
velero_aws_access_key_id     = ""
velero_aws_secret_access_key = ""
enable_lakehouse             = false

# cluster sizing
eks_endpoint_private_access  = false
eks_node_group_instance_type = ["t2.2xlarge"]
eks_node_group_capacity_type = "ON_DEMAND"
eks_node_group_scaling_config = {
  desired_size = 2
  max_size     = 2
  min_size     = 1
}
# Disk node size in gb
eks_node_disk_size = 30

create_s3_buckets = true
s3_buckets = {
  "s3_bucket"                 = "",
  "velero_storage_bucket"     = "",
  "checkpoint_storage_bucket" = "",
  "s3_backups_bucket"         = ""
}

# Image Tags
command_service_image_tag       = "1.0.6-GA"
web_console_image_tag           = "1.0.6-GA"
system_rules_ingestor_image_tag = "1.0.2-GA"
spark_image_tag                 = "3.3.0-debian-11-r26"
dataset_api_image_tag           = "1.0.6-GA"
flink_image_tag                 = "1.0.6-GA"
flink_lakehouse_image_tag       = "1.0.1"
secor_image_tag                 = "1.0.0-GA"
superset_image_tag              = "3.0.2"


# Backup image tags
redis_backup_image_tag      = "1.0.5-GA"
postgresql_backup_image_tag = "1.0.5-GA"

redirection_auth_path = "keycloak"

#smtp server confuration
smtp_enabled = "false"
smtp_config = {
  host            = ""
  user            = ""
  password        = ""
  from_address    = ""
  cert_file       = ""
  key_file        = ""
  ehlo_identity   = ""
  startTLS_policy = ""
  skip_verify     = "true"
  from_name       = "obsrv"

}
