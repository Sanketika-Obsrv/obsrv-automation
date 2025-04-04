output "private_key_pem" {
  value     = tls_private_key.private_key.private_key_pem
  sensitive = true # Ensure the private key is not exposed in the output
}

# Output the public key (public key can be exposed safely)
output "public_key_pem" {
  value = tls_private_key.private_key.public_key_pem
}