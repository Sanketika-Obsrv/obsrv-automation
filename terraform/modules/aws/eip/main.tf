locals {
  common_tags = {
    Environment   = "${var.env}"
    BuildingBlock = "${var.building_block}"
  }
}


resource "aws_eip" "kong_ingress_ip" {
  count = var.create_kong_ingress_ip ? 1 : 0

  tags = merge(
    {
      Name = "${var.building_block}-${var.env}-kong-ingress-ip"
    },
    local.common_tags,
    var.additional_tags
  )
}