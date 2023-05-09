output "name" {
  description = "The name of the bucket."
  value       = google_storage_bucket.storage_bucket.name
}