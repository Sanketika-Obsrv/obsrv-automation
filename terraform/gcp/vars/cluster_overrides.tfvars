project                       = "obsrv-gcp-oss"
building_block                = "obsrv"
env                           = "dev"
region                        = "us-central1"
gke_cluster_location          = "us-central1"
zone                          = "us-central1-a"
timezone                      = "UTC"
service_type                  = "LoadBalancer"

# cluster sizing

gke_node_pool_instance_type   = "c2d-standard-8"
gke_node_pool_scaling_config = {
  desired_size = 2
  max_size = 2
  min_size = 1
}

# Disk node size in gb
# eks_node_disk_size            = 30

# Image Tags
command_service_image_tag         = "1.0.0-GA"
web_console_image_tag             = "1.0.0-GA"
dataset_api_image_tag             = "1.0.2-GA"
secor_image_tag                   = "1.0.0-GA"
superset_image_tag                = "3.0.2"

# Image tag for each flink job
flink_release_version_map = {
  extractor             = "1.0.5-GA"
  preprocessor          = "1.0.5-GA"
  denormalizer          = "1.0.5-GA"
  transformer           = "1.0.5-GA"
  druid-router          = "1.0.5-GA"
  master-data-processor = "1.0.5-GA"
}

flink_merged_pipeline_release_version_map = {
    merged-pipeline       = "1.0.5-GA"
    master-data-processor = "1.0.5-GA"
}