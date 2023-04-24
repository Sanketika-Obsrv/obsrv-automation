output "s3_bucket" {
  value = aws_s3_bucket.storage_bucket.bucket
}

output "velero_storage_bucket" {
  value = aws_s3_bucket.velero_storage_bucket.bucket
}