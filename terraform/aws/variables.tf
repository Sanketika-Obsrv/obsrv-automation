variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}

variable "region" {
  type        = string
  description = "AWS region to create the resources. e.g.: us-east-2"
}
variable "availability_zones" {
  type        = list(string)
  description = "Enter a minimum of two AWS Availability zones. e.g.: [\"us-east-2a\", \"us-east-2b\", \"us-east-2c\"] "
}
variable "timezone" {
  type        = string
  description = "Timezone property to backup the data. Example UTC (in upper case)"
}

variable "create_kong_ingress" {
  type        = bool
  description = "Set this value to true/false to enable/disable kong ingress creation"
}

variable "create_vpc" {
  type        = bool
  description = "Set this value to true/false to enable/disable new vpc creation"
}

variable "create_velero_user" {
  type        = bool
  description = "Set this value to true/false to enable/disable new user creation for backups"
}

variable "eks_nodes_subnet_ids" {
  type        = list(string)
  description = "The VPC's subnet id which will be used to create the EKS node groups"
  default     = [""]
}

variable "eks_master_subnet_ids" {
  type        = list(string)
  description = "The VPC's subnet id which will be used to create the EKS cluster"
  default     = [""]
}

variable "velero_aws_access_key_id" {
  type        = string
  description = "AWS Access key to access bucket"
  default     = ""
}
variable "velero_aws_secret_access_key" {
  type        = string
  description = "AWS Secret access key to access bucket"
  default     = ""
}
variable "service_type" {
  type        = string
  description = "Kubernetes service type either NodePort or LoadBalancer. It is LoadBalancer by default"
  default     = "ClusterIP"
}
variable "vpc_id" {
  type        = string
  description = "Enter the existing vpc id"
  default     = ""
}
variable "cluster_logs_enabled" {
  type        = bool
  description = "Toggle to enable eks cluster logs"
  default     = true
}
variable "flink_checkpoint_store_type" {
  type        = string
  description = "Flink checkpoint store type."
  default     = "s3"
}

variable "druid_deepstorage_type" {
  type        = string
  description = "Druid deep strorage type."
  default     = "s3"
}

variable "kubernetes_storage_class" {
  type        = string
  description = "Storage class name for the Kubernetes cluster"
  default     = "gp2"
}

variable "dataset_api_container_registry" {
  type        = string
  description = "Container registry. For example docker.io/obsrv"
  default     = "sanketikahub"
}

variable "dataset_api_image_name" {
  type        = string
  description = "Dataset api image name."
  default     = "config-service-ext"
}

variable "dataset_api_image_tag" {
  type        = string
  description = "Dataset api image tag."
  default     = "1.0.2-GA"
}

variable "flink_container_registry" {
  type        = string
  description = "Container registry. For example docker.io/obsrv"
  default     = "sanketikahub"
}

variable "flink_image_tag" {
  type        = string
  description = "Flink kubernetes service name."
  default     = "1.0.2-GA"
}

variable "monitoring_grafana_oauth_configs" {
  type        = map(any)
  description = "Grafana oauth related variables. See below commented code for values that need to be passed"
}

# web console variables start
variable "web_console_configs" {
  type        = map(any)
  description = "Web console config variables. See below commented code for values that need to be passed"
}

variable "web_console_image_repository" {
  type        = string
  description = "Container registry. For example docker.io/obsrv"
  default     = "sanketikahub/obsrv-web-console"
}

variable "web_console_image_tag" {
  type        = string
  description = "web console image tag."
  default     = "1.0.2-GA"
}
# web console variables end.

variable "docker_registry_secret_dockerconfigjson" {
  type        = string
  description = "The dockerconfigjson encoded in base64 format."
}

variable "docker_registry_secret_name" {
  type        = string
  description = "The name of the secret. This will be sent back as an output which can be used in other modules"
  default     = "docker-registry-secret"
}

variable "command_service_image_tag" {
  type        = string
  description = "CommandService image tag."
  default     = "1.0.2-GA"
}

variable "oauth_configs" {
  type        = map(any)
  description = "Superset config variables. See the below commented code to know values to be passed "
}

variable "web_console_credentials" {
  type        = map(any)
  description = "web console login credentials"
}

variable "flowlogs_enabled" {
  type        = bool
  description = "Enable / disable VPC flowlogs to cloudwatch."
  default     = false
}

variable "flowlogs_retention_in_days" {
  type        = number
  description = "Retention period for the cloudwatch logs. Possible values are: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653, and 0. If you select 0, the events in the log group are always retained and never expire"
  default     = 7
}

variable "flink_release_names" {
  description = "Create release names"
  type        = map(string)
  default = {
    extractor                 = "extractor"
    preprocessor              = "preprocessor"
    denormalizer              = "denormalizer"
    transformer-ext           = "transformer-ext"
    druid-router              = "druid-router"
    master-data-processor-ext = "master-data-processor-ext"
  }
}

variable "flink_unified_pipeline_release_names" {
  description = "Create release names"
  type        = map(string)
  default = {
    unified-pipeline          = "unified-pipeline"
    master-data-processor-ext = "master-data-processor-ext"
  }
}

variable "unified_pipeline_enabled" {
  description = "Toggle to deploy unified pipeline"
  type        = bool
  default     = true
}

variable "kong_loadbalancer_annotations" {
  type        = string
  description = "Kong ingress loadbalancer annotations."
  default     = <<EOF
service.beta.kubernetes.io/aws-load-balancer-type: nlb
service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
EOF
}

variable "kong_ingress_domain" {
  type        = string
  description = "Kong ingress domain. Leave it empty if you dont have a domain name. If you have a domain, provide value such as obsrv.ai"
  default     = ""
}

variable "letsencrypt_ssl_admin_email" {
  type        = string
  description = "Letsencrypt ssl domain admin email."
  default     = "anandp@sanketika.in"
}
variable "grafana_secret_name" {
  type        = string
  description = "The name of the secret. This will be sent back as an output which can be used in other modules"
  default     = "grafana-secret"
}


variable "system_rules_ingestor_container_registry" {
  type        = string
  description = "Container registry. For example docker.io/obsrv"
  default     = "sanketikahub"
}

variable "system_rules_ingestor_image_name" {
  type        = string
  description = "Dataset api image name."
  default     = "system-rules-ingestor"
}

variable "system_rules_ingestor_image_tag" {
  type        = string
  description = "Dataset api image tag."
  default     = "1.0.2-GA"
}

variable "grafana_url" {
  type        = string
  description = "grafana url"
  default     = "http://monitoring-grafana.monitoring.svc:80"
}

variable "spark_image_repository" {
  type        = string
  description = "spark image repository."
  default     = "sanketikahub/spark"
}

variable "spark_image_tag" {
  type        = string
  description = "spark image tag."
  default     = "3.3.0-debian-11-r26_1.0.3-GA"
}

variable "secor_image_tag" {
  type        = string
  description = "secor image version"
  default     = "1.0.0-GA"
}

variable "superset_image_tag" {
  type        = string
  description = "Superset image tag."
  default     = "3.0.2"
}

variable "redis_backup_image_tag" {
  type        = string
  description = "Redis backup image tag."
  default     = "1.0.0"
}

variable "postgresql_backup_image_tag" {
  type        = string
  description = "Postgresql backup image tag."
  default     = "0.5"
}

variable "eks_node_group_scaling_config" {
  type        = map(number)
  description = "EKS node group auto scaling configuration."
}

variable "eks_node_disk_size" {
  type        = number
  description = "EKS nodes disk size"
}

variable "eks_node_group_instance_type" {
  type        = list(string)
  description = "EKS nodegroup instance types."
}

variable "eks_node_group_capacity_type" {
  type        = string
  description = "EKS node group type. Either SPOT or ON_DEMAND can be used"
}

variable "redirection_auth_path" {
  type        = string
  description = "Either obsrv or keycloak"
}

variable "smtp_enabled" {
  type        = bool
  description = "enable the smtp server"
  default     = false
}

variable "smtp_config" {
  type        = map(string)
  description = "smtp server configuration"
  default = {
    host            = ""
    user            = ""
    password        = ""
    from_address    = ""
    cert_file       = ""
    key_file        = ""
    ehlo_identity   = ""
    startTLS_policy = ""
    skip_verify     = "true"
    from_name       = "obsrv"
  }
}

variable "eks_endpoint_private_access" {
  type        = bool
  description = "API server endpoint access"
}

variable "create_s3_buckets" {
  type        = bool
  description = "Create s3 buckets"
  default     = true
}

variable "s3_buckets" {
  type        = map(string)
  description = "S3 bucket names"
  default = {
    "s3_bucket"                 = "",
    "velero_storage_bucket"     = "",
    "checkpoint_storage_bucket" = "",
    "s3_backups_bucket"         = ""
  }
}

variable "storage_provider" {
  type        = string
  description = "storage provider name e.g: aws, azure, gcp"
  default     = "aws"
}

variable "hudi_namespace" {
  type        = string
  default     = "hudi"
  description = "Apache Hudi namespace"
}

variable "hudi_prefix_path" {
  type        = string
  description = "Hudi prefix path"
  default     = "hudi"
}

variable "enable_lakehouse" {
  type        = bool
  description = "Toggle to install hudi components (hms, trino and flink job)"
}

variable "lakehouse_host" {
  type        = string
  description = "Lakehouse Host"
  default     = "http://trino.hudi.svc.cluster.local"
}

variable "lakehouse_port" {
  type        = string
  description = "Trino port"
  default     = "8080"
}

variable "lakehouse_catalog" {
  type        = string
  description = "Lakehouse Catalog name"
  default     = "lakehouse"
}

variable "lakehouse_schema" {
  type        = string
  description = "Lakehouse Schema name"
  default     = "hms"
}

variable "lakehouse_default_user" {
  type        = string
  description = "Lakehouse default user"
  default     = "admin"
}


variable "flink_image_name" {
  type        = string
  description = "Flink image name."
  default = "lakehouse-connector"
}

variable "flink_lakehouse_image_tag" {
  type        = string
  description = "Flink lakehouse image tag."
  default = "1.0.0-GA"
}
