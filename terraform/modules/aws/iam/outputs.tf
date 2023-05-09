output "s3_access_key" {
  value = aws_iam_access_key.s3_user_key.id
  sensitive = true
}

output "s3_secret_key" {
  value = aws_iam_access_key.s3_user_key.secret
  sensitive = true
}

output "velero_user_access_key" {
  value = aws_iam_access_key.velero_user_key.id
  sensitive = true
}

output "velero_user_secret_key" {
  value = aws_iam_access_key.velero_user_key.secret
  sensitive = true
}