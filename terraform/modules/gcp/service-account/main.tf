resource "google_service_account" "service_account" {
  project      = var.project
  account_id   = var.name
  display_name = var.description
}

locals {
  create_sa_binding         = (var.sa_name == "" || var.sa_namespace == "") ? false : true
  all_service_account_roles = var.service_account_roles
}

resource "google_project_iam_member" "service_account-roles" {
  for_each = toset(local.all_service_account_roles)

  project = var.project
  role    = each.value
  member  = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_service_account_iam_member" "workload_identity-role" {
  count = local.create_sa_binding == true ? 1 : 0

  service_account_id = google_service_account.service_account.name
  role    = "roles/iam.workloadIdentityUser"
  member  = "serviceAccount:${var.project}.svc.id.goog[${var.sa_namespace}/${var.sa_name}]"
}

resource "google_service_account_key" "service_account" {
  count    = var.google_service_account_key_path == "" ? 0 : 1
  service_account_id = google_service_account.service_account.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

resource "local_file" "service_account" {
  # for_each = toset(google_service_account_key.service_account)
  count    = var.google_service_account_key_path == "" ? 0 : 1
  content  = base64decode(google_service_account_key.service_account[0].private_key)
  filename = var.google_service_account_key_path
}

resource "google_storage_bucket_object" "gke_service_account" {
  count  = var.sa_key_store_bucket == "" ? 0 : 1
  name   = "service-accounts/${var.name}.json"
  source = var.google_service_account_key_path
  bucket = "${var.sa_key_store_bucket}-configs"
}