resource "aws_iam_user" "s3_user" {
  name = "${var.building_block}-${var.env}-s3-user"
  path = "/"
}

resource "aws_iam_access_key" "s3_user_key" {
  user       = aws_iam_user.s3_user.name
  depends_on = [aws_iam_user.s3_user]
}

resource "aws_iam_user_policy_attachment" "s3_user_policy" {
  user       = aws_iam_user.s3_user.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_user" "velero_user" {
  name = "${var.building_block}-${var.env}-velero-user"
  path = "/"
}

resource "aws_iam_access_key" "velero_user_key" {
  user       = aws_iam_user.velero_user.name
  depends_on = [aws_iam_user.velero_user]
}

resource "aws_iam_policy" "velero_user_policy" {
  name        = "velero_policy"
  path        = "/"
  description = "Velero Backup IAM Policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
                "ec2:DescribeVolumes",
                "ec2:DescribeSnapshots",
                "ec2:CreateTags",
                "ec2:CreateVolume",
                "ec2:CreateSnapshot",
                "ec2:DeleteSnapshot"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
          "Effect": "Allow",
          "Action": [
              "s3:GetObject",
              "s3:DeleteObject",
              "s3:PutObject",
              "s3:AbortMultipartUpload",
              "s3:ListMultipartUploadParts"
          ],
          "Resource": [
              "arn:aws:s3:::${var.velero_storage_bucket}/*"
          ]
      },
      {
          "Effect": "Allow",
          "Action": [
              "s3:ListBucket"
          ],
          "Resource": [
              "arn:aws:s3:::${var.velero_storage_bucket}"
          ]
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "velero_user_policy_attachment" {
  user       = aws_iam_user.velero_user.name
  policy_arn = aws_iam_policy.velero_user_policy.arn
}