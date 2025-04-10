variable "template_path" {
  description = "Path to the template file"
  type        = string
}

variable "template_vars" {
  description = "Variables for the template file"
  type        = map(string)
}

variable "output_path" {
  description = "Path where the generated file will be stored"
  type        = string
}
