remote_state {
  backend = "gcs"
  config = {
    project = get_env("GOOGLE_PROJECT_ID")
    location = "us-central1"
    bucket  = get_env("GOOGLE_TERRAFORM_BACKEND_BUCKET")
    prefix  = "terraform/state"
  }
}