variable "env" {
  type        = string
  description = "Environment name. All resources will be prefixed with this value."
}

variable "building_block" {
  type        = string
  description = "Building block name. All resources will be prefixed with this value."
}

variable "kubernetes_reflector_release_name" {
  type        = string
  description = "Kubernetes reflector helm release name."
  default     = "kubernetes-reflector"
}

variable "kubernetes_reflector_namespace" {
  type        = string
  description = "Kubernetes reflector namespace."
  default     = "kubernetes-reflector"
}

variable "kubernetes_reflector_create_namespace" {
  type        = bool
  description = "Create kubernetes_reflector namespace."
  default     = true
}

variable "kubernetes_reflector_wait_for_jobs" {
  type        = bool
  description = "Kubernetes reflector wait for jobs paramater."
  default     = true
}

variable "kubernetes_reflector_chart_repository" {
  type        = string
  description = "Kubernetes reflector chart repository url."
  default     = "https://emberstack.github.io/helm-charts"
}

variable "kubernetes_reflector_chart_name" {
  type        = string
  description = "Kubernetes reflector chart name."
  default     = "reflector"
}

variable "kubernetes_reflector_chart_version" {
  type        = string
  description = "Kubernetes reflector chart version."
  default     = "7.0.151"
}

variable "kubernetes_reflector_install_timeout" {
  type        = number
  description = "Kubernetes reflector chart install timeout."
  default     = 600
}

variable "docker_registry_secret_release_name" {
  type        = string
  description = "Kubernetes reflector helm release name."
  default     = "docker-registry-secret"
}

variable "docker_registry_secret_custom_values_yaml" {
  type        = string
  description = "Monitoring chart values.yaml path."
  default     = "docker_registry_secret.yaml.tfpl"
}

variable "docker_registry_secret_chart_path" {
  type        = string
  description = "S3 exporter helm chart path."
  default     = "docker-registry-secret-helm-chart"
}
variable "kubernetes_reflector_custom_values_yaml" {
  type        = string
  description = "Monitoring chart values.yaml path."
  default     = "kubernetes_reflector.yaml.tfpl"
}

variable "docker_registry_secret_dockerconfigjson" {
  type        = string
  description = "The dockerconfigjson encoded in base64 format."
  sensitive   = true
}

variable "docker_registry_secret_allowed_namespaces" {
  type        = string
  description = "Comma separated namespace names where we want to replicate the docker registry secret."
  default     = "postgresql,redis,command-service,web-console,kafka,flink,dataset-api"
}

variable "docker_registry_secret_name" {
  type        = string
  description = "The name of the secret. This will be sent back as an output which can be used in other modules"
  default     = "docker-registry-secret"
}
