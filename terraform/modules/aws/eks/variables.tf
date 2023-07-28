variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}

variable "additional_tags" {
  type        = map(string)
  description = "Additional tags for the resources. These tags will be applied to all the resources."
  default     = {}
}

variable "region" {
  type        = string
  description = "AWS region to create the resources."
  default     = "us-east-2"
}

variable "eks_master_role" {
  type        = string
  description = "EKS control plane role name."
  default     = "eks_master_role"
}

variable "eks_nodes_role" {
  type        = string
  description = "EKS data plane role name.."
  default     = "eks_nodes_role"
}

variable "eks_node_group_name" {
  type        = string
  description = "EKS node group name."
  default     = "eks_node_group"
}

variable "eks_node_group_ami_type" {
  type        = string
  description = "EKS node group AMI type."
  default     = "AL2_x86_64"
}

variable "eks_node_group_instance_type" {
  type        = list(string)
  description = "EKS nodegroup instance types."
  default     = ["t2.xlarge"]
}

variable "eks_node_group_capacity_type" {
  type        = string
  description = "EKS node group type. Either SPOT or ON_DEMAND can be used"
  default     = "SPOT"
}

variable "eks_node_group_scaling_config" {
  type        = map(number)
  description = "EKS node group auto scaling configuration."
  default = {
    desired_size = 4
    max_size     = 4
    min_size     = 0
  }
}

variable "eks_version" {
  type        = string
  description = "EKS version."
  default     = "1.25"
}

variable "eks_addons" {
  type = list(object({
    name  = string
    version = string
  }))

  default = [
    {
    name  = "kube-proxy"
    version = "v1.25.6-eksbuild.2"
    },
    {
    name  = "vpc-cni"
    version = "v1.12.6-eksbuild.1"
    },
    {
    name  = "coredns"
    version = "v1.9.3-eksbuild.2"
    },
    {
    name  = "aws-ebs-csi-driver"
    version = "v1.17.0-eksbuild.1"
    }
  ]
}

variable eks_master_subnet_ids {
  type        = list(string)
  description = "The VPC's public subnet id which will be used to create the EKS cluster."
}

variable eks_nodes_subnet_ids {
  type        = list(string)
  description = "The VPC's public subnet id which will be used to create the EKS node groups."
}

variable "eks_node_disk_size" {
  type        = number
  description = "EKS nodes disk size"
  default     = 128
}

variable "oidc_thumbprint_list" {
  type        = list(string)
  description = "Additional list of server certificate thumbprints for the OpenID Connect (OIDC) identity provider's server certificate(s)"
  default     = []
}

variable "dataset_api_sa_iam_role_name" {
  type        = string
  description = "IAM role name for dataset api service account."
  default     = "dataset-api-sa-iam-role"
}

variable "dataset_api_namespace" {
  type        = string
  description = "Dataset service namespace."
  default     = "dataset-api"
}

variable "flink_sa_iam_role_name" {
  type        = string
  description = "IAM role name for flink service account."
  default     = "flink-sa-iam-role"
}

variable "flink_namespace" {
  type        = string
  description = "Flink namespace."
  default     = "flink"
}

variable "druid_raw_sa_iam_role_name" {
  type        = string
  description = "IAM role name for druid raw service account."
  default     = "druid-raw-sa-iam-role"
}

variable "druid_raw_namespace" {
  type        = string
  description = "Druid raw namespace."
  default     = "druid-raw"
}

variable "secor_sa_iam_role_name" {
  type        = string
  description = "IAM role name for secor service account."
  default     = "secor-sa-iam-role"
}

variable "secor_namespace" {
  type        = string
  description = "Secor namespace."
  default     = "secor"
}
