data "aws_caller_identity" "current" {}

locals {
  common_tags = {
    Environment = "${var.env}"
    BuildingBlock = "${var.building_block}"
  }
  storage_bucket = "${var.building_block}-${var.env}-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "storage_bucket" {
  bucket = local.storage_bucket
  tags = merge(
    {
      Name = local.storage_bucket
    },
    local.common_tags,
    var.additional_tags)
}

resource "aws_s3_bucket" "velero_storage_bucket" {
  bucket = "velero-${local.storage_bucket}"
  tags = merge(
    {
      Name = "velero-${local.storage_bucket}"
    },
    local.common_tags,
    var.additional_tags)
}

# resource "aws_s3_object" "object" {
#     for_each = fileset("../sample-data/", "*")
#       bucket = local.storage_bucket
#       key    = each.value
#       source = "../sample-data/${each.value}"
#       source_hash = filemd5("../sample-data/${each.value}")
# }

# resource "aws_s3_bucket_policy" "s3_bucket_policy" {
#     bucket = aws_s3_bucket.storage_bucket.id
#     policy = <<POLICY
#     {
#     "Version": "2012-10-17",
#     "Statement": [
#         {
#         "Effect": "Allow",
#         "Action": "s3:ListBucket",
#         "Resource": "arn:aws:s3:::${data.aws_s3_bucket.terraform_storage_bucket.name}"
#         },
#         {
#         "Effect": "Allow",
#         "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
#         "Resource": "arn:aws:s3:::${data.aws_s3_bucket.terraform_storage_bucket.name}/terraform.tfstate"
#         }
#     ]
#     }
#     POLICY
# }