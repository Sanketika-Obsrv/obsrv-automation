output "multi_zone_public_subnets_ids" {
  value = aws_subnet.public_subnets[*].id
}

output "single_zone_public_subnets_id" {
  value = [aws_subnet.public_subnets[0].id]
}

output "vpc_id" {
  value = aws_vpc.vpc.id
}