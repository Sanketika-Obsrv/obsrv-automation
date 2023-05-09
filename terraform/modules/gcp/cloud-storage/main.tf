resource "google_storage_bucket" "storage_bucket" {
    project         = var.project
    name            = var.name
    location        = var.region
    force_destroy   = true
}