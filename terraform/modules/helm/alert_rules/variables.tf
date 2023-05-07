variable "alertrules_release_name" {
  type        = string
  description = "alertrules helm release name."
  default     = "alertrules"
}

variable "alertrules_namespace" {
  type        = string
  description = "alertrules namespace."
  default     = "monitoring"
}

variable "alertrules_chart_path" {
  type        = string
  description = "alertrules chart path."
  default     = "alert-rules-helm-chart"
}

variable "alertrules_create_namespace" {
  type        = bool
  description = "Create alertrules namespace."
  default     = true
}

variable "alertrules_custom_values_yaml" {
  type = string
  default = "alert_rules.yaml.tfpl"
}

variable "alertrules_chart_depends_on" {
  type        = any
  description = "List of helm release names that this chart depends on."
  default     = ""
}