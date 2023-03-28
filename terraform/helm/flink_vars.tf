variable "flink_release_name" {
    type        = string
    description = "Flink helm release name."
    default     = "druid-validator"
}

variable "flink_namespace" {
    type        = string
    description = "Flink namespace."
    default     = "flink"
}

variable "flink_chart_path" {
    type        = string
    description = "Flink chart path."
    default     = "../../helm_charts/flink"
}

variable "flink_chart_install_timeout" {
    type        = number
    description = "Flink chart install timeout."
    default     = 900
}

variable "flink_create_namespace" {
    type        = bool
    description = "Create flink namespace."
    default     = true
}

variable "flink_wait_for_jobs" {
    type        = bool
    description = "Flink wait for jobs paramater."
    default     = false
}

variable "flink_chart_template" {
    type        = string
    description = "Flink chart values.yaml path."
    default     = "../terraform_helm_templates/flink.yaml.tfpl"
}

variable "flink_kubernetes_service_name" {
    type        = string
    description = "Flink kubernetes service name."
    default     = "druid-validator-jobmanager"
}

variable "flink_container_registry" {
    type        = string
    description = "Container registry. For example docker.io/obsrv"
    default     = "sanketikahub"
}

variable "flink_image_name" {
    type        = string
    description = "Flink kubernetes service name."
    default     = "obsrv-core"
}

variable "flink_image_tag" {
    type        = string
    description = "Flink kubernetes service name."
    default     = "latest"
}

variable "flink_force_update" {
    type        = bool
    description = "Force update release. This is temporarily needed for github actions"
    default     = true
}

variable "flink_cleanup_on_fail" {
    type        = bool
    description = "Cleanup orphan resources on failure."
    default     = true
}

variable "flink_atomic" {
    type        = bool
    description = "Rollback on failure."
    default     = true
}