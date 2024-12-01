# Variable for the algorithm (default to RSA)
variable "key_algorithm" {
  description = "The algorithm to use for generating the private key (e.g., RSA or EC)"
  type        = string
  default     = "RSA"  # Default to RSA
}

# Variable for the key size (default to 2048)
variable "key_size" {
  description = "The size of the RSA key in bits"
  type        = number
  default     = 2048  # Default to 2048 bits
}
