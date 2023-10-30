output "name" {
  value = google_storage_bucket.storage_bucket.name
}

output "velero_storage_bucket" {
  value = google_storage_bucket.velero_storage_bucket.name
}

output "checkpoint_storage_bucket" {
  value = google_storage_bucket.checkpoint_storage_bucket.name
}