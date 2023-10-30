locals {
    common_tags = {
      Environment = "${var.env}"
      BuildingBlock = "${var.building_block}"
    }
    environment_name = "${var.building_block}-${var.env}"
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${local.environment_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "${local.environment_name}"

  default_node_pool {
    name       = var.aks_nodepool_name
    node_count = var.aks_node_count
    vm_size    = var.aks_node_size
  }

  identity {
    type = var.aks_cluster_identity
  }

  tags = merge(
      local.common_tags,
      var.additional_tags
      )
}

resource "local_file" "kubeconfig" {
  content      = azurerm_kubernetes_cluster.aks.kube_config_raw
  filename     = "${local.environment_name}-kubeconfig.yaml"
}