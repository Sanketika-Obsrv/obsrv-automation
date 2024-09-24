output "dataset_api_sa_annotations" {
  value = aws_iam_role.dataset_api_sa_iam_role.arn
}

output "spark_sa_annotations" {
  value = aws_iam_role.spark_sa_iam_role.arn
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

output "spark_namespace" {
  value = var.spark_namespace
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

output "s3_exporter_sa_annotations" {
  value = aws_iam_role.s3_exporter_sa_iam_role.arn
}

output "postgresql_backup_sa_iam_role" {
  value = aws_iam_role.postgresql_backup_sa_iam_role.arn
}

output "s3_exporter_namespace" {
  value = var.s3_exporter_namespace
}

output "postgresql_namespace" {
  value = var.postgresql_namespace
}

output "redis_backup_sa_iam_role" {
  value = aws_iam_role.redis_backup_sa_iam_role.arn
}

output "redis_namespace" {
  value = var.redis_namespace
}
