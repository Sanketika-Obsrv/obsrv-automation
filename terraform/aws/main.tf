terraform {
  backend "s3" {}
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "helm" {
  alias = "helm"
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
  source                        = "../modules/aws/eks"
  env                           = var.env
  building_block                = var.building_block
  depends_on                    = [module.vpc]
  region                        = var.region
  cluster_logs_enabled          = var.cluster_logs_enabled
  eks_master_subnet_ids         = var.create_vpc ? module.vpc[0].multi_zone_public_subnets_ids : var.eks_master_subnet_ids
  eks_nodes_subnet_ids          = var.create_vpc ? module.vpc[0].single_zone_public_subnets_id : var.eks_nodes_subnet_ids
  eks_node_group_instance_type  = var.eks_node_group_instance_type
  eks_node_group_capacity_type  = var.eks_node_group_capacity_type
  eks_node_group_scaling_config = var.eks_node_group_scaling_config
  eks_node_disk_size            = var.eks_node_disk_size
  eks_endpoint_private_access   = var.eks_endpoint_private_access
}

module "iam" {
  source                = "../modules/aws/iam"
  env                   = var.env
  count                 = var.create_velero_user ? 1 : 0
  building_block        = var.building_block
  velero_storage_bucket = var.create_s3_buckets ? module.s3[0].velero_storage_bucket : var.s3_buckets.velero_storage_bucket
}

module "s3" {
  count          = var.create_s3_buckets ? 1 : 0
  source         = "../modules/aws/s3"
  env            = var.env
  building_block = var.building_block
}

resource "random_string" "connectors_encryption_key" {
  length  = 32
  special = false
}

resource "random_string" "data_encryption_key" {
  length  = 32
  special = false
}

# module "dataset_api" {
#   source                         = "../modules/helm/dataset_api"
#   env                            = var.env
#   building_block                 = var.building_block
#   dataset_api_container_registry = var.dataset_api_container_registry
#   dataset_api_image_name         = var.dataset_api_image_name
#   dataset_api_image_tag          = var.dataset_api_image_tag
#   grafana_url                    = var.grafana_url
#   postgresql_obsrv_username      = module.postgresql.postgresql_obsrv_username
#   postgresql_obsrv_user_password = module.postgresql.postgresql_obsrv_user_password
#   postgresql_obsrv_database      = module.postgresql.postgresql_obsrv_database
#   dataset_api_sa_annotations     = "eks.amazonaws.com/role-arn: ${module.eks.dataset_api_sa_annotations}"
#   # dataset_api_chart_depends_on   = [module.postgresql, module.kafka,module.kubernetes_reflector]
#   dataset_api_chart_depends_on            = [module.postgresql, module.kafka]
#   denorm_redis_namespace                  = module.redis_denorm.redis_namespace
#   denorm_redis_release_name               = module.redis_denorm.redis_release_name
#   dedup_redis_namespace                   = module.redis_dedup.redis_namespace
#   dedup_redis_release_name                = module.redis_dedup.redis_release_name
#   druid_cluster_release_name              = module.druid_raw_cluster.druid_cluster_release_name
#   druid_cluster_namespace                 = module.druid_raw_cluster.druid_cluster_namespace
#   command_service_release_name            = module.command_service.command_service_release_name
#   command_service_namespace               = module.command_service.command_service_namespace
#   dataset_api_namespace                   = module.eks.dataset_api_namespace
#   docker_registry_secret_dockerconfigjson = var.docker_registry_secret_dockerconfigjson
#   # docker_registry_secret_name    = module.kubernetes_reflector.docker_registry_secret_name
#   docker_registry_secret_name = var.docker_registry_secret_name
#   s3_bucket                   = var.create_s3_buckets ? module.s3[0].s3_bucket : var.s3_buckets.s3_bucket
#   encryption_key              = resource.random_string.connectors_encryption_key.result
#   service_type                = var.service_type
#   s3_region                   = var.region
#   storage_provider            = var.storage_provider
#   enable_lakehouse            = var.enable_lakehouse
#   lakehouse_host              = var.lakehouse_host
#   lakehouse_port              = var.lakehouse_port
#   lakehouse_catalog           = var.lakehouse_catalog
#   lakehouse_schema            = var.lakehouse_schema
#   lakehouse_default_user      = var.lakehouse_default_user     
# }

# module "secor" {
#   source                   = "../modules/helm/secor"
#   env                      = var.env
#   building_block           = var.building_block
#   secor_image_tag          = var.secor_image_tag
#   secor_sa_annotations     = "eks.amazonaws.com/role-arn: ${module.eks.secor_sa_iam_role}"
#   secor_chart_depends_on   = [module.kafka, module.eks_storage_class]
#   timezone                 = var.timezone
#   secor_namespace          = module.eks.secor_namespace
#   cloud_storage_bucket     = var.create_s3_buckets ? module.s3[0].s3_bucket : var.s3_buckets.s3_bucket
#   kubernetes_storage_class = var.kubernetes_storage_class
#   region                   = var.region
# }

# module "submit_ingestion" {
#   source                            = "../modules/helm/submit_ingestion"
#   env                               = var.env
#   building_block                    = var.building_block
#   submit_ingestion_chart_depends_on = [module.kafka, module.druid_raw_cluster]
#   druid_cluster_release_name        = module.druid_raw_cluster.druid_cluster_release_name
#   druid_cluster_namespace           = module.druid_raw_cluster.druid_cluster_namespace
# }

# module "velero" {
#   source                       = "../modules/helm/velero"
#   env                          = var.env
#   building_block               = var.building_block
#   cloud_provider               = "aws"
#   velero_backup_bucket         = var.create_s3_buckets ? module.s3[0].velero_storage_bucket : var.s3_buckets.velero_storage_bucket
#   velero_backup_bucket_region  = var.region
#   velero_aws_access_key_id     = var.create_velero_user ? module.iam[0].velero_user_access_key : var.velero_aws_access_key_id
#   velero_aws_secret_access_key = var.create_velero_user ? module.iam[0].velero_user_secret_key : var.velero_aws_secret_access_key
# }

# module "alert_rules" {
#   source                      = "../modules/helm/alert_rules"
#   alertrules_chart_depends_on = [module.monitoring]
# }

# module "web_console" {
#   source              = "../modules/helm/web_console"
#   env                 = var.env
#   building_block      = var.building_block
#   web_console_configs = var.web_console_configs
#   # depends_on                   = [module.eks, module.kubernetes_reflector, module.monitoring]
#   depends_on                              = [module.eks, module.monitoring, module.dataset_api]
#   web_console_image_repository            = var.web_console_image_repository
#   web_console_image_tag                   = var.web_console_image_tag
#   docker_registry_secret_dockerconfigjson = var.docker_registry_secret_dockerconfigjson
#   # docker_registry_secret_name  = module.kubernetes_reflector.docker_registry_secret_name
#   docker_registry_secret_name = var.docker_registry_secret_name
#   kong_ingress_domain         = var.kong_ingress_domain != "" ? var.kong_ingress_domain : "${module.eip.kong_ingress_ip.public_ip}.sslip.io"
#   grafana_secret_name         = var.grafana_secret_name
#   service_type                = var.service_type
# }

# module "system_rules_ingestor" {
#   source                                   = "../modules/helm/system-rules-ingestor"
#   env                                      = var.env
#   building_block                           = var.building_block
#   system_rules_ingestor_container_registry = var.system_rules_ingestor_container_registry
#   system_rules_ingestor_image_name         = var.system_rules_ingestor_image_name
#   system_rules_ingestor_image_tag          = var.system_rules_ingestor_image_tag
#   depends_on                               = [module.dataset_api, module.monitoring]
# }
# module "volume_autoscaler" {
#   source         = "../modules/helm/volume_autoscaler"
#   env            = var.env
#   building_block = var.building_block
#   depends_on     = [module.eks, module.eks_storage_class, module.monitoring]
# }

# module "s3_exporter" {
#   source                     = "../modules/helm/s3_exporter"
#   env                        = var.env
#   building_block             = var.building_block
#   s3_exporter_sa_annotations = "eks.amazonaws.com/role-arn: ${module.eks.s3_exporter_sa_annotations}"
#   s3_exporter_namespace      = module.eks.s3_exporter_namespace
#   depends_on                 = [module.eks, module.monitoring]
#   s3_region                  = var.region
# }

# module "command_service" {
#   source                                  = "../modules/helm/command_service"
#   env                                     = var.env
#   command_service_chart_depends_on        = [module.flink, module.postgresql, module.druid_raw_cluster, module.dataset_api]
#   command_service_image_tag               = var.command_service_image_tag
#   postgresql_obsrv_username               = module.postgresql.postgresql_obsrv_username
#   postgresql_obsrv_user_password          = module.postgresql.postgresql_obsrv_user_password
#   postgresql_obsrv_database               = module.postgresql.postgresql_obsrv_database
#   druid_cluster_release_name              = module.druid_raw_cluster.druid_cluster_release_name
#   druid_cluster_namespace                 = module.druid_raw_cluster.druid_cluster_namespace
#   flink_namespace                         = module.flink.flink_namespace
#   docker_registry_secret_dockerconfigjson = var.docker_registry_secret_dockerconfigjson
#   # docker_registry_secret_name      = module.kubernetes_reflector.docker_registry_secret_name
#   docker_registry_secret_name = var.docker_registry_secret_name
#   kafka_release_name          = module.kafka.kafka_release_name
#   kafka_namespace             = module.kafka.kafka_namespace
#   enable_lakehouse            = var.enable_lakehouse
# }

# module "postgresql_backup" {
#   source                              = "../modules/helm/postgresql_backup"
#   env                                 = var.env
#   building_block                      = var.building_block
#   postgresql_backup_postgres_user     = module.postgresql.postgresql_admin_username
#   postgresql_backup_postgres_host     = module.postgresql.postgresql_service_name
#   postgresql_backup_postgres_password = module.postgresql.postgresql_admin_password
#   postgresql_backup_s3_bucket         = var.create_s3_buckets ? module.s3[0].s3_backups_bucket : var.s3_buckets.s3_backups_bucket
#   postgresql_backup_sa_annotations    = "eks.amazonaws.com/role-arn: ${module.eks.postgresql_backup_sa_iam_role}"
#   postgresql_backup_namespace         = module.eks.postgresql_namespace
#   # depends_on                          = [module.eks, module.kubernetes_reflector]
#   depends_on                              = [module.eks]
#   docker_registry_secret_dockerconfigjson = var.docker_registry_secret_dockerconfigjson
#   # docker_registry_secret_name         = module.kubernetes_reflector.docker_registry_secret_name
#   docker_registry_secret_name = var.docker_registry_secret_name
# }

# module "kubernetes_reflector" {
#   source                                  = "../modules/helm/kubernetes_reflector"
#   env                                     = var.env
#   building_block                          = var.building_block
#   docker_registry_secret_dockerconfigjson = var.docker_registry_secret_dockerconfigjson
#   depends_on                              = [module.eks]
# }

# module "kafka_message_exporter" {
#   source                                  = "../modules/helm/kafka_message_exporter"
#   env                                     = var.env
#   building_block                          = var.building_block
#   docker_registry_secret_dockerconfigjson = var.docker_registry_secret_dockerconfigjson
#   # docker_registry_secret_name = module.kubernetes_reflector.docker_registry_secret_name
#   docker_registry_secret_name = var.docker_registry_secret_name
#   # depends_on                  = [module.kafka, module.kubernetes_reflector]
#   depends_on = [module.kafka]
# }

module "flowlogs" {
  count                      = var.flowlogs_enabled ? 1 : 0
  source                     = "../modules/aws/flowlogs"
  env                        = var.env
  building_block             = var.building_block
  vpc_id                     = var.create_vpc ? module.vpc[0].vpc_id : var.vpc_id
  flowlogs_retention_in_days = var.flowlogs_retention_in_days
}

module "eip" {
  source         = "../modules/aws/eip"
  env            = var.env
  building_block = var.building_block
}

# module "kong_ingress" {
#   source                        = "../modules/helm/kong_ingress"
#   env                           = var.env
#   building_block                = var.building_block
#   count                         = var.create_kong_ingress ? 1 : 0
#   depends_on                    = [module.eks, module.eip, module.monitoring, module.superset, module.web_console, module.dataset_api]
#   kong_loadbalancer_annotations = var.kong_loadbalancer_annotations
#   kong_ingress_aws_eip_ids      = module.eip.kong_ingress_ip.id
#   kong_ingress_aws_subnet_ids   = join(",", module.vpc[0].single_zone_public_subnets_id)
# }

# module "kong_ingress_routes" {
#   source              = "../modules/helm/kong_ingress_routes"
#   count               = var.create_kong_ingress ? 1 : 0
#   env                 = var.env
#   building_block      = var.building_block
#   depends_on          = [module.kong_ingress]
#   kong_ingress_domain = var.kong_ingress_domain != "" ? var.kong_ingress_domain : "${module.eip.kong_ingress_ip.public_ip}.sslip.io"
# }

# module "cert_manager" {
#   source         = "../modules/helm/cert_manager"
#   count          = var.create_kong_ingress ? 1 : 0
#   env            = var.env
#   building_block = var.building_block
#   depends_on     = [module.kong_ingress, module.monitoring]
# }

# module "letsencrypt_ssl" {
#   source                      = "../modules/helm/letsencrypt_ssl"
#   count                       = var.create_kong_ingress ? 1 : 0
#   env                         = var.env
#   building_block              = var.building_block
#   depends_on                  = [module.cert_manager, module.kong_ingress, module.monitoring, module.kubernetes_reflector, module.superset, module.web_console, module.dataset_api]
#   kong_ingress_domain         = var.kong_ingress_domain != "" ? var.kong_ingress_domain : "${module.eip.kong_ingress_ip.public_ip}.sslip.io"
#   letsencrypt_ssl_admin_email = var.letsencrypt_ssl_admin_email
# }

module "eks_storage_class" {
  source         = "../modules/helm/eks_storage_class"
  env            = var.env
  building_block = var.building_block
  depends_on     = [module.eks]
}

module "get_kubeconfig" {
  source         = "../modules/aws/get_kubeconfig"
  env            = var.env
  building_block = var.building_block
  region         = var.region
}

# module "postgresql_migration" {
#   source                                = "../modules/helm/postgresql_migration"
#   env                                   = var.env
#   building_block                        = var.building_block
#   postgresql_admin_username             = module.postgresql.postgresql_admin_username
#   postgresql_admin_password             = module.postgresql.postgresql_admin_password
#   postgresql_migration_chart_depends_on = [module.postgresql]
#   postgresql_url                        = module.postgresql.postgresql_service_name
#   web_console_credentials               = var.web_console_credentials
#   monitoring_grafana_oauth_configs      = var.monitoring_grafana_oauth_configs
#   oauth_configs                         = var.oauth_configs
#   kong_ingress_domain                   = var.kong_ingress_domain != "" ? var.kong_ingress_domain : "${module.eip.kong_ingress_ip.public_ip}.sslip.io"
#   postgresql_superset_user_password     = module.postgresql.postgresql_superset_user_password
#   postgresql_druid_raw_user_password    = module.postgresql.postgresql_druid_raw_user_password
#   postgresql_obsrv_user_password        = module.postgresql.postgresql_obsrv_user_password
#   data_encryption_key                   = resource.random_string.data_encryption_key.result
#   postgresql_keycloak_user_password     = module.postgresql.postgresql_keycloak_user_password
#   postgresql_hms_user_password          = module.postgresql.postgresql_hms_user_password
#   enable_lakehouse                      = var.enable_lakehouse
# }

# module "trino" {
#   source          = "../modules/helm/trino"
#   count           = var.enable_lakehouse ? 1 : 0
#   trino_namespace = var.hudi_namespace
#   trino_lakehouse_metadata = {
#     "hive.s3.aws-access-key" = var.create_velero_user ? module.iam[0].s3_access_key : var.velero_aws_access_key_id
#     "hive.s3.aws-secret-key" = var.create_velero_user ? module.iam[0].s3_secret_key : var.velero_aws_secret_access_key
#   }
# }

# module "hms" {
#   source        = "../modules/helm/hive_meta_store"
#   count         = var.enable_lakehouse ? 1 : 0
#   hms_namespace = var.hudi_namespace
#   hms_db_metadata = {
#     "DATABASE_HOST"     = "postgresql-hl.postgresql.svc"
#     "DATABASE_DB"       = module.postgresql.postgresql_hms_database
#     "DATABASE_USER"     = module.postgresql.postgresql_hms_username
#     "DATABASE_PASSWORD" = module.postgresql.postgresql_hms_user_password
#     "WAREHOUSE_DIR"     = "s3a://${module.s3[0].s3_bucket}/${var.hudi_prefix_path}/"
#     "THRIFT_PORT"       = "9083"
#   }
#   hadoop_metadata = {
#     "fs.s3a.access.key" = var.create_velero_user ? module.iam[0].s3_access_key : var.velero_aws_access_key_id
#     "fs.s3a.secret.key" = var.create_velero_user ? module.iam[0].s3_secret_key : var.velero_aws_secret_access_key
#   }
# }

# module "lakehouse-connector" {
#   source                              = "../modules/helm/lakehouse-connector"
#   count                               = var.enable_lakehouse ? 1 : 0
#   env                                 = var.env
#   building_block                      = var.building_block
#   flink_container_registry            = var.flink_container_registry
#   flink_lakehouse_image_tag           = var.flink_lakehouse_image_tag
#   flink_image_name                    = var.flink_image_name
#   flink_checkpoint_store_type         = var.flink_checkpoint_store_type
#   flink_chart_depends_on              = [module.kafka, module.postgresql_migration, module.redis_dedup, module.redis_denorm]
#   postgresql_obsrv_username           = module.postgresql.postgresql_obsrv_username
#   postgresql_obsrv_user_password      = module.postgresql.postgresql_obsrv_user_password
#   postgresql_obsrv_database           = module.postgresql.postgresql_obsrv_database
#   checkpoint_base_url                 = "s3://${module.s3[0].checkpoint_storage_bucket}"
#   denorm_redis_namespace              = module.redis_denorm.redis_namespace
#   denorm_redis_release_name           = module.redis_denorm.redis_release_name
#   dedup_redis_namespace               = module.redis_dedup.redis_namespace
#   dedup_redis_release_name            = module.redis_dedup.redis_release_name
#   flink_sa_annotations                = "eks.amazonaws.com/role-arn: ${module.eks.flink_sa_iam_role}"
#   flink_namespace                     = module.eks.flink_namespace
#   postgresql_service_name             = module.postgresql.postgresql_service_name
#   enable_lakehouse                    = var.enable_lakehouse
#   postgresql_hms_username             = module.postgresql.postgresql_hms_username
#   postgresql_hms_user_password        = module.postgresql.postgresql_hms_user_password
#   hudi_bucket                         = module.s3[0].s3_bucket
#   hudi_prefix_path                    = var.hudi_prefix_path
#   hadoop_metadata                     = {
#     "fs.s3a.access.key" = var.create_velero_user ? module.iam[0].s3_access_key : var.velero_aws_access_key_id
#     "fs.s3a.secret.key" = var.create_velero_user ? module.iam[0].s3_secret_key : var.velero_aws_secret_access_key
#   }
# }

# module "spark" {
#   source = "../modules/helm/spark"
#   # depends_on                            = [ module.postgresql, module.kubernetes_reflector ]
#   depends_on                = [module.postgresql]
#   env                       = var.env
#   building_block            = var.building_block
#   kubernetes_storage_class  = var.kubernetes_storage_class
#   spark_image_repository    = var.spark_image_repository
#   spark_image_tag           = var.spark_image_tag
#   postgresql_obsrv_username = module.postgresql.postgresql_obsrv_username
#   postgresql_obsrv_password = module.postgresql.postgresql_obsrv_user_password
#   postgresql_obsrv_database = module.postgresql.postgresql_obsrv_database
#   # docker_registry_secret_name           = module.kubernetes_reflector.docker_registry_secret_name
#   docker_registry_secret_name = var.docker_registry_secret_name
#   s3_bucket                   = var.create_s3_buckets ? module.s3[0].s3_bucket : var.s3_buckets.s3_bucket
#   druid_cluster_release_name  = module.druid_raw_cluster.druid_cluster_release_name
#   druid_cluster_namespace     = module.druid_raw_cluster.druid_cluster_namespace
#   redis_namespace             = module.redis_denorm.redis_namespace
#   redis_release_name          = module.redis_denorm.redis_release_name
#   cloud_provider              = "aws"
#   s3_region                   = var.region
#   encryption_key              = resource.random_string.connectors_encryption_key.result
#   spark_sa_annotations        = "eks.amazonaws.com/role-arn: ${module.eks.spark_sa_annotations}"
#   spark_sa_role               = module.eks.spark_sa_annotations
# }
