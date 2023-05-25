data "google_project" "current" {
  project_id = var.project
}

locals {
  storage_bucket = "${var.building_block}-${var.env}-${data.google_project.current.number}"
}

resource "google_storage_bucket" "storage_bucket" {
  project         = var.project
  name            = local.storage_bucket
  location        = var.region
  force_destroy   = true

  versioning {
    enabled = true
  }
}

resource "google_storage_bucket" "checkpoint_storage_bucket" {
  project         = var.project
  name            = "checkpoint-${local.storage_bucket}"
  location        = var.region
  force_destroy   = true

  versioning {
    enabled = true
  }
}

resource "google_storage_bucket" "velero_storage_bucket" {
  project         = var.project
  name            = "velero-${local.storage_bucket}"
  location        = var.region
  force_destroy   = true

  versioning {
    enabled = true
  }
}
