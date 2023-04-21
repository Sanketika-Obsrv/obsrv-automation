# We use this data provider to expose an access token for communicating with the GKE cluster.
data "google_client_config" "client" {}

# Use this datasource to access the Terraform account's email for Kubernetes permissions.
data "google_client_openid_userinfo" "terraform_user" {}

module "networking" {
  source = "./modules/vpc-network"

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
  source = "./modules/cloud-storage"

  name        = "${var.building_block}-${var.env}-bucket"
  project     = var.project
  region      = var.region
}

module "gke_service_account" {
  source = "./modules/gke-service-account"

  name        = "${var.building_block}-${var.cluster_service_account_name}"
  project     = var.project
  description = var.cluster_service_account_description
}

module "gke_cluster" {
  source = "./modules/gke-cluster"

  name                          = "${var.building_block}-${var.env}-cluster"

  project                       = var.project
  location                      = var.zone
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
  provider = google-beta

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

    # disk_size_gb = "25"
    # disk_type    = var.kubernetes_storage_class
    preemptible  = true

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

# # This is a workaround for the Kubernetes and Helm providers as Terraform doesn't currently support passing in module
# # outputs to providers directly.
# data "template_file" "gke_host_endpoint" {
#   template = module.gke_cluster.endpoint
# }

# data "template_file" "access_token" {
#   template = data.google_client_config.client.access_token
# }

# data "template_file" "cluster_ca_certificate" {
#   template = module.gke_cluster.cluster_ca_certificate
# }