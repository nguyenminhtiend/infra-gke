terraform {
  backend "gcs" {
    bucket = "rich-principle-469207-v0-terraform-state"
    prefix = "terraform/state/dev"
  }
}
