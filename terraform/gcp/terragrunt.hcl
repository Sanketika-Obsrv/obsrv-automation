remote_state {
  backend = "gcs"
  config = {
    # project = getenv("GOOGLE_PROJECT_ID")
    project = "obsrv-gcp"
    location = "us-central1"
    # bucket  = getenv("GOOGLE_TERRAFORM_BACKEND_BUCKET")
    bucket  = "obsrv-gcp-dev-configs"
    prefix  = "terraform/state"
  }
}