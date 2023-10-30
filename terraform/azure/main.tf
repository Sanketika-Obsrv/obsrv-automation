terraform {
  backend "azurerm" {}
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
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

provider "azurerm" {
  features {}
}

module "network" {
  source          = "../modules/azure/network"
}

module "aks" {
  source              = "../modules/azure/aks"
  resource_group_name = module.network.resource_group_name
}

module "storage" {
  source              = "../modules/azure/storage"
  resource_group_name = module.network.resource_group_name
}

provider "helm" {
  kubernetes {
    host                   = module.aks.kubernetes_host
    client_certificate     = module.aks.client_certificate
    client_key             = module.aks.client_key
    cluster_ca_certificate = module.aks.cluster_ca_certificate
  }
}

module "promtail" {
  source                    = "../modules/helm/promtail"
  env                       = var.env
  building_block            = var.building_block
  promtail_chart_depends_on = [module.loki]
}

module "loki" {
  source         = "../modules/helm/loki"
  env            = var.env
  building_block = var.building_block
  depends_on     = [module.aks, module.monitoring]
}

module "monitoring" {
  source         = "../modules/helm/monitoring"
  env            = var.env
  building_block = var.building_block
  depends_on     = [module.aks]
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

module "grafana_configs" {
  source                           = "../modules/helm/grafana_configs"
  env                              = var.env
  building_block                   = var.building_block
  grafana_configs_chart_depends_on = [module.monitoring]
}

module "postgresql" {
  source         = "../modules/helm/postgresql"
  env            = var.env
  building_block = var.building_block
  depends_on     = [module.aks]
}

module "kafka" {
  source         = "../modules/helm/kafka"
  env            = var.env
  building_block = var.building_block
  depends_on     = [module.aks]
}

module "flink" {
  source                         = "../modules/helm/flink"
  env                            = var.env
  building_block                 = var.building_block
  flink_container_registry       = var.flink_container_registry
  flink_image_tag                = var.flink_image_tag
  azure_storage_account_name     = module.storage.azurerm_storage_account_name
  azure_storage_account_key      = module.storage.azurerm_storage_account_key
  flink_checkpoint_store_type    = var.flink_checkpoint_store_type
  flink_chart_depends_on         = [module.kafka]
  postgresql_flink_user_password = module.postgresql.postgresql_flink_user_password
}

module "druid_raw_cluster" {
  source                             = "../modules/helm/druid_raw_cluster"
  env                                = var.env
  building_block                     = var.building_block
  azure_storage_account_name         = module.storage.azurerm_storage_account_name
  azure_storage_account_key          = module.storage.azurerm_storage_account_key
  azure_storage_container            = module.storage.azurerm_storage_container
  druid_deepstorage_type             = var.druid_deepstorage_type
  druid_raw_cluster_chart_depends_on = [module.postgresql, module.druid_operator]
  kubernetes_storage_class           = var.kubernetes_storage_class
  druid_raw_user_password            = module.postgresql.postgresql_druid_raw_user_password
}

module "druid_operator" {
  source         = "../modules/helm/druid_operator"
  env            = var.env
  building_block = var.building_block
  depends_on     = [module.aks]
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

module "secor" {
  source                 = "../modules/helm/secor"
  env                    = var.env
  building_block         = var.building_block
  secor_chart_depends_on = [module.kafka]
}

module "submit_ingestion" {
  source                            = "../modules/helm/submit_ingestion"
  env                               = var.env
  building_block                    = var.building_block
  submit_ingestion_chart_depends_on = [module.kafka, module.druid_raw_cluster]
}

module "alert_rules" {
  source                       = "../modules/helm/alert_rules"
  env                          = var.env
  building_block               = var.building_block
  alertrules_chart_depends_on  = [module.monitoring]
}

module "command_service" {
  source                           = "../modules/helm/command_service"
  env                              = var.env
  command_service_chart_depends_on = [module.flink, module.postgresql]
  command_service_image_tag        = var.command_service_image_tag
  postgresql_obsrv_username        = module.postgresql.postgresql_obsrv_username
  postgresql_obsrv_user_password   = module.postgresql.postgresql_obsrv_user_password
  postgresql_obsrv_database        = module.postgresql.postgresql_obsrv_database
  flink_namespace                  = module.flink.flink_namespace
}