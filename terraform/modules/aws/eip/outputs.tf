output "kong_ingress_ip" {
  value = aws_eip.kong_ingress_ip
}

output "eip_allocation_id" {
  value = aws_eip.kong_ingress_ip[0].id
}