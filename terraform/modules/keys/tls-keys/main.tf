provider "tls" {}

# Define the RSA private key resource
resource "tls_private_key" "private_key" {
  algorithm = var.key_algorithm     # Algorithm passed from the variable (RSA)
  rsa_bits  = var.key_size          # RSA key size (e.g., 2048) passed from the variable
}

# Step 2: Store the private key in a PEM file
resource "local_file" "private_key" {
  content  = tls_private_key.private_key.private_key_pem
  filename = "../../helmcharts/private_key.pem"  # Save it in the current module directory
}

# Step 3: Store the public key in a PEM file
resource "local_file" "public_key" {
  content  = tls_private_key.private_key.public_key_pem  # PEM format of the public key
  filename = "../../helmcharts/public_key.pem"  # Save it in the current module directory
}
