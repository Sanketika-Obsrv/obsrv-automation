variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}

variable "eks_storage_class_release_name" {
  type        = string
  description = "EKS storage class helm release name."
  default     = "eks-storage-class"
}

variable "eks_storage_class_install_timeout" {
  type        = number
  description = "EKS storage class chart install timeout."
  default     = 300
}

variable "eks_storage_class_chart_path" {
  type        = string
  description = "EKS storage class helm chart path."
  default     = "eks-storage-class-helm-chart"
}

variable "volume_encryption" {
  description = "Enable EBS volume encryption for EKS nodes"
  type        = bool
  default     = true
}

variable "eks_storage_class_custom_values_yaml" {
  type    = string
  default = "eks_storage_class.yaml.tfpl"
}