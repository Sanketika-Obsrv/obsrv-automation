variable "private_key" {
  description = "The private key to be included in the YAML file"
  type        = string
}

variable "public_key" {
  description = "The public key to be included in the YAML file"
  type        = string
}
variable "file_path" {
  description = "The path where the global-cloud-values.yaml file should be created"
  type        = string
}
