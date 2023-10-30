locals {
  common_tags = {
    Environment   = "${var.env}"
    BuildingBlock = "${var.building_block}"
  }
  availability_zones = [for zone in ["a", "b", "c"] : "${var.region}${zone}"]
}

resource "aws_vpc" "vpc" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = var.vpc_instance_tenancy
  tags = merge(
    {
      Name = "${var.building_block}-${var.env}-vpc"
    },
    local.common_tags,
    var.additional_tags)
}

resource "aws_subnet" "public_subnets" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = element(var.public_subnet_cidrs, count.index)
  availability_zone       = element(local.availability_zones, count.index)
  map_public_ip_on_launch = var.auto_assign_public_ip

  tags = merge(
    {
      Name = "${var.building_block}-${var.env}-public-subnet-${count.index}"
    },
    local.common_tags,
    var.additional_tags)
}

resource "aws_internet_gateway" "internet_gateway" {
   vpc_id = aws_vpc.vpc.id

  tags = merge(
    {
      Name = "${var.building_block}-${var.env}-igw"
    },
    local.common_tags,
    var.additional_tags)
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = var.igw_cidr
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = merge(
    {
      Name = "${var.building_block}-${var.env}-public-route-table"
    },
    local.common_tags,
    var.additional_tags)
}

resource "aws_route_table_association" "public_subnet_association" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
  route_table_id = aws_route_table.public_route_table.id
}
