# project config
project                       = "obsrv"
building_block                = "obsrv"
env                           = "dev"
region                        = "us-central1"
gke_cluster_location          = "us-central1"
zone                          = "us-central1-a"
service_type                  = "LoadBalancer"

# cluster sizing
gke_node_pool_instance_type   = "c2d-standard-8"
gke_node_pool_scaling_config = {
  desired_size = 2
  max_size = 3
  min_size = 0
}

# cluster networking
create_network                = true
network                       = ""
subnetwork                    = ""
cluster_secondary_range_name  = ""
services_secondary_range_name = ""

# cluster node pool configuration
gke_node_default_disk_size_gb = 30