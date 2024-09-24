locals {
  common_tags = {
    Environment   = "${var.env}"
    BuildingBlock = "${var.building_block}"
  }
}

resource "aws_eip" "kong_ingress_ip" {
  tags = merge(
    {
    Name = "${var.building_block}-${var.env}-kong-ingress-ip"
    },
    local.common_tags,
    var.additional_tags)
}