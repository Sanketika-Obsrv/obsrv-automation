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
    host                   = module.eks.kubernetes_host
    cluster_ca_certificate = module.eks.kubernetes_ca_certificate
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["--region", "${var.region}", "eks", "get-token", "--cluster-name", "${var.building_block}-${var.env}-eks"]
    }
  }
}

module "vpc" {
  source         = "../modules/aws/vpc"
  env            = var.env
  building_block = var.building_block
}

module "eks" {
  source                = "../modules/aws/eks"
  env                   = var.env
  building_block        = var.building_block
  eks_master_subnet_ids = module.vpc.multi_zone_public_subnets_ids
  eks_nodes_subnet_ids  = module.vpc.single_zone_public_subnets_id
}

module "iam" {
  source                = "../modules/aws/iam"
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
  depends_on                       = [module.eks]
}

module "superset" {
  source                            = "../modules/helm/superset"
  env                               = var.env
  building_block                    = var.building_block
  postgresql_admin_username         = module.postgresql.postgresql_admin_username
  postgresql_admin_password         = module.postgresql.postgresql_admin_password
  postgresql_superset_user_password = module.postgresql.postgresql_superset_user_password
  superset_chart_depends_on         = [module.postgresql, module.redis]
  redis_namespace                   = module.redis.redis_namespace
  redis_release_name                = module.redis.redis_release_name
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
  depends_on           = [module.eks]
}

module "redis" {
  source               = "../modules/helm/redis"
  env                  = var.env
  building_block       = var.building_block
  depends_on           = [module.eks]
}

module "kafka" {
  source         = "../modules/helm/kafka"
  env            = var.env
  building_block = var.building_block
  depends_on     = [module.eks]
}

module "flink" {
  source                         = "../modules/helm/flink"
  env                            = var.env
  building_block                 = var.building_block
  flink_container_registry       = var.flink_container_registry
  flink_image_tag                = var.flink_image_tag
  # s3_access_key                  = module.iam.s3_access_key
  # s3_secret_key                  = module.iam.s3_secret_key
  flink_checkpoint_store_type    = var.flink_checkpoint_store_type
  flink_chart_depends_on         = [module.kafka, module.postgresql, module.redis]
  postgresql_obsrv_username      = module.postgresql.postgresql_obsrv_username
  postgresql_obsrv_user_password = module.postgresql.postgresql_obsrv_user_password
  postgresql_obsrv_database      = module.postgresql.postgresql_obsrv_database
  checkpoint_base_url            = "s3://${module.s3.checkpoint_storage_bucket}"
  redis_namespace                = module.redis.redis_namespace
  redis_release_name             = module.redis.redis_release_name
  flink_sa_annotations           = "eks.amazonaws.com/role-arn: ${module.eks.flink_sa_iam_role}"
  flink_namespace                = module.eks.flink_namespace
}

module "druid_raw_cluster" {
  source                             = "../modules/helm/druid_raw_cluster"
  env                                = var.env
  building_block                     = var.building_block
#  s3_access_key                      = module.iam.s3_access_key
#  s3_secret_key                      = module.iam.s3_secret_key
  s3_bucket                          = module.s3.s3_bucket
  druid_deepstorage_type             = var.druid_deepstorage_type
  druid_raw_cluster_chart_depends_on = [module.postgresql, module.druid_operator]
  kubernetes_storage_class           = var.kubernetes_storage_class
  druid_raw_user_password            = module.postgresql.postgresql_druid_raw_user_password
  druid_raw_sa_annotations           = "eks.amazonaws.com/role-arn: ${module.eks.druid_raw_sa_iam_role}"
  druid_cluster_namespace            = module.eks.druid_raw_namespace
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
  dataset_api_chart_depends_on       = [module.postgresql, module.kafka]
  redis_namespace                    = module.redis.redis_namespace
  redis_release_name                 = module.redis.redis_release_name
  dataset_api_namespace              = module.eks.dataset_api_namespace
}

module "secor" {
  source                  = "../modules/helm/secor"
  env                     = var.env
  building_block          = var.building_block
  secor_sa_annotations    = "eks.amazonaws.com/role-arn: ${module.eks.secor_sa_iam_role}"
  secor_chart_depends_on  = [module.kafka]
  secor_namespace         = module.eks.secor_namespace
  cloud_storage_bucket    = module.s3.s3_bucket
  storage_class           = var.storage_class
}

module "submit_ingestion" {
  source                            = "../modules/helm/submit_ingestion"
  env                               = var.env
  building_block                    = var.building_block
  submit_ingestion_chart_depends_on = [module.kafka, module.druid_raw_cluster]
}

module "velero" {
  source                       = "../modules/helm/velero"
  env                          = var.env
  building_block               = var.building_block
  cloud_provider               = "aws"
  velero_backup_bucket         = module.s3.velero_storage_bucket
  velero_backup_bucket_region  = var.region
  velero_aws_access_key_id     = module.iam.velero_user_access_key
  velero_aws_secret_access_key = module.iam.velero_user_secret_key
}

module "alert_rules" {
  source                       = "../modules/helm/alert_rules"
  alertrules_chart_depends_on  = [module.monitoring]
}