remote_state {
  backend = "gcs"
  config = {
    project = get_env("GOOGLE_PROJECT_ID")
    location = get_env("GOOGLE_TERRAFORM_BACKEND_LOCATION")
    bucket  = get_env("GOOGLE_TERRAFORM_BACKEND_BUCKET")
    prefix  = "terraform/state"
  }
}