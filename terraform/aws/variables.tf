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

variable "kubernetes_storage_class" {
  type        = string
  description = "Storage class name for the Kubernetes cluster"
  default     = "gp2"
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

variable "docker_registry_secret_dockerconfigjson" {
  type        = string
  description = "The dockerconfigjson encoded in base64 format."
}

variable "docker_registry_secret_name" {
  type        = string
  description = "The name of the secret. This will be sent back as an output which can be used in other modules"
  default     = "docker-registry-secret"
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

