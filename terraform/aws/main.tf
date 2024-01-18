terraform {
  backend "s3" {}
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
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

provider "aws" {
  region  = var.region
}

provider "helm" {
  alias  = "helm"
  kubernetes {
    config_path = "~/.kube/config"
  }
}

module "vpc" {
  source             = "../modules/aws/vpc"
  env                = var.env
  count              = var.create_vpc ? 1 : 0
  building_block     = var.building_block
  region             = var.region
  availability_zones = var.availability_zones
}

module "eks" {
  source                = "../modules/aws/eks"
  env                   = var.env
  building_block        = var.building_block
  cluster_logs_enabled  = var.cluster_logs_enabled
  eks_master_subnet_ids = var.create_vpc ? module.vpc[0].multi_zone_public_subnets_ids : var.eks_master_subnet_ids
  eks_nodes_subnet_ids  = var.create_vpc ? module.vpc[0].single_zone_public_subnets_id : var.eks_nodes_subnet_ids
  region                = var.region
  depends_on            = [module.vpc]
}

module "iam" {
  source                = "../modules/aws/iam"
  count                 = var.create_velero_user ? 1 : 0
  env                   = var.env
  building_block        = var.building_block
  velero_storage_bucket = module.s3.velero_storage_bucket
}

module "s3" {
  source         = "../modules/aws/s3"
  env            = var.env
  building_block = var.building_block
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
  depends_on     = [module.eks, module.monitoring]
}

module "monitoring" {
  source                           = "../modules/helm/monitoring"
  env                              = var.env
  building_block                   = var.building_block
  service_type                     = var.service_type
  depends_on                       = [module.eks]
}

module "superset" {
  source                            = "../modules/helm/superset"
  env                               = var.env
  building_block                    = var.building_block
  postgresql_admin_username         = module.postgresql.postgresql_admin_username
  postgresql_admin_password         = module.postgresql.postgresql_admin_password
  postgresql_superset_user_password = module.postgresql.postgresql_superset_user_password
  superset_chart_depends_on         = [module.postgresql_migration, module.redis_dedup]
  redis_namespace                   = module.redis_dedup.redis_namespace
  redis_release_name                = module.redis_dedup.redis_release_name
  postgresql_service_name           = module.postgresql.postgresql_service_name
  service_type                      = var.service_type
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
  depends_on           = [module.eks, module.monitoring]
}

module "redis_dedup" {
  source               = "../modules/helm/redis_dedup"
  env                  = var.env
  building_block       = var.building_block
  depends_on           = [module.eks, module.monitoring]
}

module "redis_denorm" {
  source               = "../modules/helm/redis_denorm"
  env                  = var.env
  building_block       = var.building_block
  depends_on           = [module.eks, module.monitoring]
}

module "kafka" {
  source         = "../modules/helm/kafka"
  env            = var.env
  building_block = var.building_block
  depends_on     = [module.eks, module.monitoring]
}

module "flink" {
  source                              = "../modules/helm/flink"
  env                                 = var.env
  building_block                      = var.building_block
  flink_container_registry            = var.flink_container_registry
  flink_image_tag                     = var.flink_image_tag
  flink_merged_pipeline_release_names = var.flink_merged_pipeline_release_names
  flink_release_names                 = var.flink_release_names
  merged_pipeline_enabled             = var.merged_pipeline_enabled
  flink_checkpoint_store_type         = var.flink_checkpoint_store_type
  flink_chart_depends_on              = [module.kafka, module.postgresql_migration, module.redis_dedup, module.redis_denorm]
  postgresql_obsrv_username           = module.postgresql.postgresql_obsrv_username
  postgresql_obsrv_user_password      = module.postgresql.postgresql_obsrv_user_password
  postgresql_obsrv_database           = module.postgresql.postgresql_obsrv_database
  checkpoint_base_url                 = "s3://${module.s3.checkpoint_storage_bucket}"
  denorm_redis_namespace              = module.redis_denorm.redis_namespace
  denorm_redis_release_name           = module.redis_denorm.redis_release_name
  dedup_redis_namespace               = module.redis_dedup.redis_namespace
  dedup_redis_release_name            = module.redis_dedup.redis_release_name
  flink_sa_annotations                = "eks.amazonaws.com/role-arn: ${module.eks.flink_sa_iam_role}"
  flink_namespace                     = module.eks.flink_namespace
  postgresql_service_name             = module.postgresql.postgresql_service_name
}

module "druid_raw_cluster" {
  source                             = "../modules/helm/druid_raw_cluster"
  env                                = var.env
  building_block                     = var.building_block
#  s3_access_key                      = module.iam.s3_access_key
#  s3_secret_key                      = module.iam.s3_secret_key
  s3_bucket                          = module.s3.s3_bucket
  druid_deepstorage_type             = var.druid_deepstorage_type
  druid_raw_cluster_chart_depends_on = [module.postgresql_migration, module.druid_operator]
  kubernetes_storage_class           = var.kubernetes_storage_class
  druid_raw_user_password            = module.postgresql.postgresql_druid_raw_user_password
  druid_raw_sa_annotations           = "eks.amazonaws.com/role-arn: ${module.eks.druid_raw_sa_iam_role}"
  druid_cluster_namespace            = module.eks.druid_raw_namespace
  service_type                       = var.service_type
}

module "druid_operator" {
  source          = "../modules/helm/druid_operator"
  env             = var.env
  building_block  = var.building_block
  depends_on      = [module.eks]
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

resource "random_string" "data_encryption_key" {
  length = 32
  special = false
}

module "dataset_api" {
  source                             = "../modules/helm/dataset_api"
  env                                = var.env
  building_block                     = var.building_block
  dataset_api_container_registry     = var.dataset_api_container_registry
  dataset_api_image_tag              = var.dataset_api_image_tag
  # dataset_api_postgres_user_password = module.postgresql.postgresql_dataset_api_user_password
  postgresql_obsrv_username          = module.postgresql.postgresql_obsrv_username
  postgresql_obsrv_user_password     = module.postgresql.postgresql_obsrv_user_password
  postgresql_obsrv_database          = module.postgresql.postgresql_obsrv_database
  dataset_api_sa_annotations         = "eks.amazonaws.com/role-arn: ${module.eks.dataset_api_sa_annotations}"
  dataset_api_chart_depends_on       = [module.postgresql_migration, module.kafka]
  denorm_redis_namespace             = module.redis_denorm.redis_namespace
  denorm_redis_release_name          = module.redis_denorm.redis_release_name
  dedup_redis_namespace              = module.redis_dedup.redis_namespace
  dedup_redis_release_name           = module.redis_dedup.redis_release_name
  dataset_api_namespace              = module.eks.dataset_api_namespace
  s3_bucket                          = module.s3.s3_bucket
  service_type                       = var.service_type
}

module "secor" {
  source                    = "../modules/helm/secor"
  env                       = var.env
  building_block            = var.building_block
  secor_sa_annotations      = "eks.amazonaws.com/role-arn: ${module.eks.secor_sa_iam_role}"
  secor_chart_depends_on    = [module.kafka]
  timezone                   = var.timezone
  secor_namespace           = module.eks.secor_namespace
  cloud_storage_bucket      = module.s3.s3_bucket
  kubernetes_storage_class  = var.kubernetes_storage_class
  region                    = var.region
}

module "submit_ingestion" {
  source                            = "../modules/helm/submit_ingestion"
  env                               = var.env
  building_block                    = var.building_block
  submit_ingestion_chart_depends_on = [module.kafka, module.druid_raw_cluster]
  druid_cluster_release_name        = module.druid_raw_cluster.druid_cluster_release_name
  druid_cluster_namespace           = module.druid_raw_cluster.druid_cluster_namespace
}

module "velero" {
  source                       = "../modules/helm/velero"
  env                          = var.env
  building_block               = var.building_block
  cloud_provider               = "aws"
  velero_backup_bucket         = module.s3.velero_storage_bucket
  velero_backup_bucket_region  = var.region
  velero_aws_access_key_id     = var.create_velero_user ?  module.iam[0].velero_user_access_key : var.velero_aws_access_key_id
  velero_aws_secret_access_key = var.create_velero_user ? module.iam[0].velero_user_secret_key : var.velero_aws_secret_access_key 
}

module "alert_rules" {
  source                       = "../modules/helm/alert_rules"
  alertrules_chart_depends_on  = [module.monitoring]
}

module "web_console" {
  source                           = "../modules/helm/web_console"
  env                              = var.env
  building_block                   = var.building_block
  web_console_configs              = var.web_console_configs
  depends_on                       = [module.eks, module.monitoring]
  web_console_image_repository     = var.web_console_image_repository
  web_console_image_tag            = var.web_console_image_tag
  service_type                     = var.service_type
}

module "get_kubeconfig" {
  source         = "../modules/aws/get_kubeconfig"
  env            = var.env
  building_block = var.building_block
  region         = var.region
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

module "postgresql_migration" {
  source                                = "../modules/helm/postgresql_migration"
  env                                   = var.env
  building_block                        = var.building_block
  postgresql_admin_username             = module.postgresql.postgresql_admin_username
  postgresql_admin_password             = module.postgresql.postgresql_admin_password
  postgresql_migration_chart_depends_on = [module.postgresql]
  postgresql_url                        = module.postgresql.postgresql_service_name
  postgresql_superset_user_password     = module.postgresql.postgresql_superset_user_password
  postgresql_druid_raw_user_password    = module.postgresql.postgresql_druid_raw_user_password
  postgresql_obsrv_user_password        = module.postgresql.postgresql_obsrv_user_password
  data_encryption_key                   = resource.random_string.data_encryption_key.result
}
