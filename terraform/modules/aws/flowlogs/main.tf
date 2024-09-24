locals {
  common_tags = {
    Environment   = "${var.env}"
    BuildingBlock = "${var.building_block}"
  }
}

data "aws_iam_policy_document" "flowlogs_iam_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "flowlogs_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy" "flowlogs_iam_role_policy" {
  name   = "${var.building_block}-${var.env}-vpc-flowlogs-role-policy"
  role   = aws_iam_role.flowlogs_iam_role.id
  policy = data.aws_iam_policy_document.flowlogs_iam_policy.json
}

resource "aws_iam_role" "flowlogs_iam_role" {
  name               = "${var.building_block}-${var.env}-vpc-flowlogs-role"
  assume_role_policy = data.aws_iam_policy_document.flowlogs_assume_role.json
}

resource "aws_cloudwatch_log_group" "vpc_flowlogs_cloudwatch_group" {
  name              = "${var.building_block}-${var.env}-vpc-flowlogs-log-group"
  retention_in_days = var.flowlogs_retention_in_days
  tags = merge(
    {
      Name = "${var.building_block}-${var.env}-vpc-flowlogs-log-group"
    },
    local.common_tags,
    var.additional_tags)
}

resource "aws_flow_log" "vpc_flowlogs" {
  iam_role_arn    = aws_iam_role.flowlogs_iam_role.arn
  log_destination = aws_cloudwatch_log_group.vpc_flowlogs_cloudwatch_group.arn
  traffic_type    = var.flow_log_traffic_type
  vpc_id          = var.vpc_id
  log_format      = var.log_format
  tags = merge(
    {
      Name = "${var.building_block}-${var.env}-vpc-flowlogs"
    },
    local.common_tags,
    var.additional_tags)
}