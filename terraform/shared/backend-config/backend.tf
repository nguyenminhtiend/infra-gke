terraform {
  backend "gcs" {
    bucket = "infra-gke-469413-terraform-state"
    prefix = "terraform/state"
  }
}
