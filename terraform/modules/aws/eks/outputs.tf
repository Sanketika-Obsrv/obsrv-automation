output "dataset_api_sa_annotations" {
  value = aws_iam_role.dataset_api_sa_iam_role.arn
}

output "flink_sa_iam_role" {
  value = aws_iam_role.flink_sa_iam_role.arn
}

output "druid_raw_sa_iam_role" {
  value = aws_iam_role.druid_raw_sa_iam_role.arn
}

output "secor_sa_iam_role" {
  value = aws_iam_role.secor_sa_iam_role.arn
}

output "dataset_api_namespace" {
  value = var.dataset_api_namespace
}

output "druid_raw_namespace" {
  value = var.druid_raw_namespace
}

output "flink_namespace" {
  value = var.flink_namespace
}

output "secor_namespace" {
  value = var.secor_namespace
}