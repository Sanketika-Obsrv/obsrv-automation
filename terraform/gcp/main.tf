terraform {
  # backend "gcs" {}

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.63.1"
    }

    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 4.63.1"
    }
    local = {
      source = "hashicorp/local"
      version  = "~> 2.0"
    }
    helm = {
      source = "hashicorp/helm"
      version  = "~> 2.0"
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region

  scopes = [
    # Default scopes
    "https://www.googleapis.com/auth/compute",
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/ndev.clouddns.readwrite",
    "https://www.googleapis.com/auth/devstorage.full_control",

    # Required for google_client_openid_userinfo
    "https://www.googleapis.com/auth/userinfo.email",
  ]
}

provider "google-beta" {
  project = var.project
  region  = var.region

  scopes = [
    # Default scopes
    "https://www.googleapis.com/auth/compute",
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/ndev.clouddns.readwrite",
    "https://www.googleapis.com/auth/devstorage.full_control",

    # Required for google_client_openid_userinfo
    "https://www.googleapis.com/auth/userinfo.email",
  ]
}

module "networking" {
  source = "../modules/gcp/vpc-network"

  name_prefix           = "${var.building_block}-${var.env}"
  project               = var.project
  region                = var.region

  cidr_block            = var.vpc_cidr_block
  secondary_cidr_block  = var.vpc_secondary_cidr_block

  public_subnetwork_secondary_range_name = var.public_subnetwork_secondary_range_name
  public_services_secondary_range_name   = var.public_services_secondary_range_name
  public_services_secondary_cidr_block   = var.public_services_secondary_cidr_block
  private_services_secondary_cidr_block  = var.private_services_secondary_cidr_block
  secondary_cidr_subnetwork_width_delta  = var.secondary_cidr_subnetwork_width_delta
  secondary_cidr_subnetwork_spacing      = var.secondary_cidr_subnetwork_spacing

  igw_cidr              = var.igw_cidr
}

module "cloud_storage" {
  source = "../modules/gcp/cloud-storage"

  name        = "${var.building_block}-${var.env}-bucket"
  project     = var.project
  region      = var.region
}

module "gke_service_account"{
  source = "../modules/gcp/service-account"
  name        = "${var.building_block}-${var.cluster_service_account_name}"
  project     = var.project
  description = var.cluster_service_account_description
  service_account_roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer"
  ]
  google_service_account_key_path = "./.keys/${var.building_block}-${var.cluster_service_account_name}.json"
}

module "gcs_service_account"{
  source = "../modules/gcp/service-account"
  name        = "${var.building_block}-${var.gcs_service_account_name}"
  project     = var.project
  description = var.gcs_service_account_description
  service_account_roles = ["roles/storage.objectAdmin"]
  google_service_account_key_path = "./.keys/${var.building_block}-${var.gcs_service_account_name}.json"
}

module "gke_cluster" {
  source = "../modules/gcp/gke-cluster"

  name                          = "${var.building_block}-${var.env}-cluster"
  project                       = var.project
  location                      = var.zone # can also specify a region here
  zone                          = var.zone # has to be a zone, else one instance per zone will be created in the region.
  network                       = module.networking.network

  subnetwork                    = module.networking.public_subnetwork
  cluster_secondary_range_name  = module.networking.public_subnetwork_secondary_range_name
  services_secondary_range_name = module.networking.public_services_secondary_range_name

  # When creating a private cluster, the 'master_ipv4_cidr_block' has to be defined and the size must be /28
  master_ipv4_cidr_block        = var.gke_master_ipv4_cidr_block

  # This setting will make the cluster private
  enable_private_nodes          = "true"

  # To make testing easier, we keep the public endpoint available. In production, we highly recommend restricting access to only within the network boundary, requiring your users to use a bastion host or VPN.
  disable_public_endpoint       = "false"

  # With a private cluster, it is highly recommended to restrict access to the cluster master
  # However, for testing purposes we will allow all inbound traffic.
  master_authorized_networks_config = [
    {
      cidr_blocks = [
        {
          cidr_block   = var.igw_cidr[0]
          display_name = "IGW"
        },
      ]
    },
  ]

  enable_vertical_pod_autoscaling = var.enable_vertical_pod_autoscaling

  alternative_default_service_account = var.override_default_node_pool_service_account ? module.gke_service_account.email : null

  resource_labels = {
    environment = var.env

  }
}

resource "google_container_node_pool" "node_pool" {
  provider = google

  name     = "${var.building_block}-${var.env}-pool"
  project  = var.project
  location = var.zone
  cluster  = module.gke_cluster.name

  initial_node_count = var.gke_node_pool_scaling_config["desired_size"]

  autoscaling {
    min_node_count = var.gke_node_pool_scaling_config["min_size"]
    max_node_count = var.gke_node_pool_scaling_config["max_size"]
  }

  management {
    auto_repair  = "true"
    auto_upgrade = "true"
  }

  node_config {
    image_type   = "COS_CONTAINERD"
    machine_type = var.gke_node_pool_instance_type

    tags = [
      module.networking.public
    ]

    disk_size_gb = "20"
    # disk_type    = var.kubernetes_storage_class
    preemptible  = var.gke_node_pool_preemptible

    service_account = module.gke_service_account.email

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  lifecycle {
    ignore_changes = [initial_node_count]
  }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }
}

resource "null_resource" "configure_kubectl" {
  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials ${module.gke_cluster.name} --region ${var.zone} --project ${var.project}"

    # Use environment variables to allow custom kubectl config paths
    environment = {
      KUBECONFIG = var.kubectl_config_path != "" ? var.kubectl_config_path : ""
    }
  }

  depends_on = [google_container_node_pool.node_pool]
}

# resource "kubernetes_cluster_role_binding" "user" {
#   metadata {
#     name = "admin-user"
#   }

#   role_ref {
#     kind      = "ClusterRole"
#     name      = "cluster-admin"
#     api_group = "rbac.authorization.k8s.io"
#   }

#   subject {
#     kind      = "User"
#     name      = data.google_client_openid_userinfo.terraform_user.email
#     api_group = "rbac.authorization.k8s.io"
#   }

#   subject {
#     kind      = "Group"
#     name      = "system:masters"
#     api_group = "rbac.authorization.k8s.io"
#   }
# }

# We use this data provider to expose an access token for communicating with the GKE cluster.
data "google_client_config" "client" {}

# Use this datasource to access the Terraform account's email for Kubernetes permissions.
data "google_client_openid_userinfo" "terraform_user" {}


provider "kubernetes" {
  host                   = module.gke_cluster.endpoint
  token                  = data.google_client_config.client.access_token
  cluster_ca_certificate = module.gke_cluster.cluster_ca_certificate
}

provider "helm" {
  kubernetes {
    host                   = module.gke_cluster.endpoint
    token                  = data.google_client_config.client.access_token
    cluster_ca_certificate = module.gke_cluster.cluster_ca_certificate
  }
}

data "template_file" "gke_host_endpoint" {
  template = module.gke_cluster.endpoint
}

data "template_file" "access_token" {
  template = data.google_client_config.client.access_token
}

data "template_file" "cluster_ca_certificate" {
  template = module.gke_cluster.cluster_ca_certificate
}

module "monitoring" {
  source          = "../modules/helm/monitoring"
  env             = var.env
  building_block  = var.building_block
  depends_on      = [module.gke_cluster]
}

module "loki" {
  source         = "../modules/helm/loki"
  env            = var.env
  building_block = var.building_block
  depends_on     = [module.gke_cluster, module.monitoring]
}

module "promtail" {
  source                    = "../modules/helm/promtail"
  env                       = var.env
  building_block            = var.building_block
  promtail_chart_depends_on = [module.loki]
}

module "grafana_configs" {
  source                           = "../modules/helm/grafana_configs"
  env                              = var.env
  building_block                   = var.building_block
  grafana_configs_chart_depends_on = [module.monitoring]
}

module "postgresql" {
  source               = "../modules/helm/postgresql"
  env                  = var.env
  building_block       = var.building_block
  depends_on           = [module.gke_cluster]
}

module "kafka" {
  source         = "../modules/helm/kafka"
  env            = var.env
  building_block = var.building_block
  depends_on     = [module.gke_cluster]
}

module "superset" {
  source                            = "../modules/helm/superset"
  env                               = var.env
  building_block                    = var.building_block
  postgresql_admin_username         = module.postgresql.postgresql_admin_username
  postgresql_admin_password         = module.postgresql.postgresql_admin_password
  postgresql_superset_user_password = module.postgresql.postgresql_superset_user_password
  superset_chart_depends_on         = [module.postgresql]
}

module "flink" {
  source                         = "../modules/helm/flink"
  env                            = var.env
  building_block                 = var.building_block
  flink_container_registry       = var.flink_container_registry
  flink_image_tag                = var.flink_image_tag
  google_service_account_key_path = "./.keys/${var.building_block}-${var.gcs_service_account_name}.json"
  flink_checkpoint_store_type    = var.flink_checkpoint_store_type
  flink_chart_depends_on         = [module.kafka]
  postgresql_flink_user_password = module.postgresql.postgresql_flink_user_password
}

module "druid_operator" {
  source          = "../modules/helm/druid_operator"
  env             = var.env
  building_block  = var.building_block
  depends_on      = [module.gke_cluster]
}

module "druid_raw_cluster" {
  source                             = "../modules/helm/druid_raw_cluster"
  env                                = var.env
  building_block                     = var.building_block
  gcs_bucket                         = module.cloud_storage.name
  druid_deepstorage_type             = var.druid_deepstorage_type
  kubernetes_storage_class           = var.kubernetes_storage_class_raw
  druid_raw_user_password            = module.postgresql.postgresql_druid_raw_user_password
  druid_raw_cluster_chart_depends_on = [module.postgresql, module.druid_operator]
}

module "kafka_exporter" {
  source                          = "../modules/helm/kafka_exporter"
  env                             = var.env
  building_block                  = var.building_block
  kafka_exporter_chart_depends_on = [module.kafka, module.monitoring]
}

module "postgresql_exporter" {
  source                               = "../modules/helm/postgresql_exporter"
  env                                  = var.env
  building_block                       = var.building_block
  postgresql_exporter_chart_depends_on = [module.postgresql, module.monitoring]
}

module "druid_exporter" {
  source                          = "../modules/helm/druid_exporter"
  env                             = var.env
  building_block                  = var.building_block
  druid_exporter_chart_depends_on = [module.druid_raw_cluster, module.monitoring]
}

module "dataset_api" {
  source                             = "../modules/helm/dataset_api"
  env                                = var.env
  building_block                     = var.building_block
  dataset_api_container_registry     = var.dataset_api_container_registry
  dataset_api_image_tag              = var.dataset_api_image_tag
  dataset_api_postgres_user_password = module.postgresql.postgresql_dataset_api_user_password
  dataset_api_sa_annotations         = "this-needs-to: be-implemented-and-added"
  dataset_api_chart_depends_on       = [module.postgresql, module.kafka]
}

# module "secor" {
#   source                  = "../modules/helm/secor"
#   env                     = var.env
#   region                  = var.region
#   building_block          = var.building_block
#   kubernetes_storage_class = var.kubernetes_storage_class_raw
#   cloud_storage_bucket    = module.cloud_storage.name
#   google_service_account_key_path = "./.keys/${var.building_block}-${var.gcs_service_account}.json"
#   secor_chart_depends_on  = [module.kafka]
# }

# # module "submit_ingestion" {
# #   source                            = "../modules/helm/submit_ingestion"
# #   env                               = var.env
# #   building_block                    = var.building_block
# #   submit_ingestion_chart_depends_on = [module.kafka, module.druid_raw_cluster]
# # }

# # module "alert_rules" {
# #   source                       = "../modules/helm/alert_rules"
# #   env                          = var.env
# #   building_block               = var.building_block
# #   alertrules_chart_depends_on  = [module.monitoring]
# # }