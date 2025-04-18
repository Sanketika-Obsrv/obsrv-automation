# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY A GKE CLUSTER
# This module deploys a GKE cluster, a managed, production-ready environment for deploying containerized applications.
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

locals {
  workload_identity_config = !var.enable_workload_identity ? [] : var.identity_namespace == null ? [{
    identity_namespace = "${var.project}.svc.id.goog" }] : [{ identity_namespace = var.identity_namespace
  }]
}

# ---------------------------------------------------------------------------------------------------------------------
# Create the GKE Cluster
# We want to make a cluster with no node pools, and manage them all with the fine-grained google_container_node_pool resource
# ---------------------------------------------------------------------------------------------------------------------

resource "google_container_cluster" "cluster" {
  provider    = google

  name        = var.name
  description = var.description

  project    = var.project
  location   = var.location
  network    = var.network
  subnetwork = var.subnetwork

  logging_service    = "none"
  monitoring_service = "none"
  min_master_version = local.kubernetes_version
  deletion_protection = var.deletion_protection

  # Whether to enable legacy Attribute-Based Access Control (ABAC). RBAC has significant security advantages over ABAC.
  enable_legacy_abac = var.enable_legacy_abac

  # The API requires a node pool or an initial count to be defined; that initial count creates the
  # "default node pool" with that # of nodes.
  # So, we need to set an initial_node_count of 1. This will make a default node
  # pool with server-defined defaults that Terraform will immediately delete as
  # part of Create. This leaves us in our desired state- with a cluster master
  # with no node pools.
  remove_default_node_pool = true

  # initial_node_count = 1 ## Uncomment of node_pool is not defined


  node_pool {
    name = "default-pool"
    initial_node_count = 1

    node_config {
      image_type   = "COS_CONTAINERD"
      machine_type = var.gke_node_pool_instance_type

      tags = var.gke_node_pool_network_tags

      disk_size_gb = var.gke_node_default_disk_size_gb
      disk_type    = var.kubernetes_storage_class
      preemptible  = var.gke_node_pool_preemptible

      service_account = var.alternative_default_service_account

      oauth_scopes = [
        "https://www.googleapis.com/auth/cloud-platform",
      ]

      confidential_nodes {
        enabled = true
      }

      shielded_instance_config {
        enable_secure_boot          = true
        enable_integrity_monitoring = true
      }
    }
  }

  ## Uncomment of node_pool is not defined
  # If we have an alternative default service account to use, set on the node_config so that the default node pool can
  # be created successfully.
  # dynamic "node_config" {

  #   # Ideally we can do `for_each = var.alternative_default_service_account != null ? [object] : []`, but due to a
  #   # terraform bug, this doesn't work. See https://github.com/hashicorp/terraform/issues/21465. So we simulate it using
  #   # a for expression.
  #   for_each = [
  #     for x in [var.alternative_default_service_account] : x if var.alternative_default_service_account != null
  #   ]

  #   content {
  #     service_account = node_config.value
  #   }
  # }

  # ip_allocation_policy.use_ip_aliases defaults to true, since we define the block `ip_allocation_policy`
  ip_allocation_policy {
    // Choose the range, but let GCP pick the IPs within the range
    cluster_secondary_range_name  = var.cluster_secondary_range_name
    services_secondary_range_name = var.services_secondary_range_name
  }

  # We can optionally control access to the cluster
  # See https://cloud.google.com/kubernetes-engine/docs/how-to/private-clusters
  private_cluster_config {
    enable_private_endpoint = var.disable_public_endpoint
    enable_private_nodes    = var.enable_private_nodes
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  addons_config {
    http_load_balancing {
      disabled = !var.http_load_balancing
    }

    horizontal_pod_autoscaling {
      disabled = !var.horizontal_pod_autoscaling
    }

    network_policy_config {
      disabled = !var.enable_network_policy
    }

    gcp_filestore_csi_driver_config {
      enabled = var.gcp_filestore_csi_driver
    }

    gce_persistent_disk_csi_driver_config {
      enabled = var.gce_persistent_disk_csi_driver
    }
  }

  network_policy {
    enabled = var.enable_network_policy

    # Tigera (Calico Felix) is the only provider
    provider = var.enable_network_policy ? "CALICO" : "PROVIDER_UNSPECIFIED"
  }

  vertical_pod_autoscaling {
    enabled = var.enable_vertical_pod_autoscaling
  }

  # master_auth {
  #   username = var.basic_auth_username
  #   password = var.basic_auth_password
  # }

  dynamic "master_authorized_networks_config" {
    for_each = var.master_authorized_networks_config
    content {
      dynamic "cidr_blocks" {
        for_each = lookup(master_authorized_networks_config.value, "cidr_blocks", [])
        content {
          cidr_block   = cidr_blocks.value.cidr_block
          display_name = lookup(cidr_blocks.value, "display_name", null)
        }
      }
    }
  }

  maintenance_policy {
    daily_maintenance_window {
      start_time = var.maintenance_start_time
    }
  }

  lifecycle {
    ignore_changes = [
      # Since we provide `remove_default_node_pool = true`, the `node_config` is only relevant for a valid construction of
      # the GKE cluster in the initial creation. As such, any changes to the `node_config` should be ignored.
      node_config,node_pool
    ]
  }

  # If var.gsuite_domain_name is non-empty, initialize the cluster with a G Suite security group
  dynamic "authenticator_groups_config" {
    for_each = [
      for x in [var.gsuite_domain_name] : x if var.gsuite_domain_name != null
    ]

    content {
      security_group = "gke-security-groups@${authenticator_groups_config.value}"
    }
  }

  # If var.secrets_encryption_kms_key is non-empty, create ´database_encryption´ -block to encrypt secrets at rest in etcd
  dynamic "database_encryption" {
    for_each = [
      for x in [var.secrets_encryption_kms_key] : x if var.secrets_encryption_kms_key != null
    ]

    content {
      state    = "ENCRYPTED"
      key_name = database_encryption.value
    }
  }

  dynamic "workload_identity_config" {
    for_each = local.workload_identity_config

    content {
      workload_pool = workload_identity_config.value.identity_namespace
    }
  }

  resource_labels = var.resource_labels
}

resource "google_container_node_pool" "node_pool" {
  provider = google

  name     = "${var.building_block}-${var.env}-pool"
  project  = var.project
  location = var.zone
  cluster  = google_container_cluster.cluster.name

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

    tags = var.gke_node_pool_network_tags

    disk_size_gb = var.gke_node_default_disk_size_gb
    disk_type    = var.kubernetes_storage_class
    preemptible  = var.gke_node_pool_preemptible

    service_account = var.alternative_default_service_account

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    confidential_nodes {
      enabled = true
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
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

# ---------------------------------------------------------------------------------------------------------------------
# Prepare locals to keep the code cleaner
# ---------------------------------------------------------------------------------------------------------------------

locals {
  latest_version     = data.google_container_engine_versions.location.latest_master_version
  kubernetes_version = var.kubernetes_version != "latest" ? var.kubernetes_version : local.latest_version
  network_project    = var.network_project != "" ? var.network_project : var.project
}

# ---------------------------------------------------------------------------------------------------------------------
# Pull in data
# ---------------------------------------------------------------------------------------------------------------------

// Get available master versions in our location to determine the latest version
data "google_container_engine_versions" "location" {
  location = var.location
  project  = var.project
}

